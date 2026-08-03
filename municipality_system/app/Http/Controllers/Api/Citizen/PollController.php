<?php

namespace App\Http\Controllers\Api\Citizen;

use App\Http\Controllers\Controller;
use App\Models\Poll;
use App\Models\PollOption;
use App\Models\PollVote;
use App\Models\User;
use App\Services\GeoBroadcastTargetingService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class PollController extends Controller
{
    public function __construct(private readonly GeoBroadcastTargetingService $targeting)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $user = $request->user();
        $this->closeExpiredPolls();
        $this->syncActivePollsForUser($user);

        $polls = Poll::query()
            ->whereHas('recipients', fn ($query) => $query->where('user_id', $user->id))
            ->whereIn('status', ['active', 'closed'])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->with(['options', 'votes' => fn ($query) => $query->where('citizen_id', $user->id)])
            ->withCount('votes')
            ->orderByRaw("CASE WHEN status = 'active' THEN 0 ELSE 1 END")
            ->orderByDesc('created_at')
            ->paginate($request->integer('per_page', 30));

        $polls->getCollection()->transform(fn (Poll $poll) => $this->formatPoll($poll, $user));

        return response()->json($polls);
    }

    public function show(Request $request, Poll $poll): JsonResponse
    {
        $user = $request->user();
        $this->closeExpiredPolls();
        $this->syncPollForUser($poll, $user);

        abort_unless($poll->recipients()->where('user_id', $user->id)->exists(), 404);

        $poll->load(['options', 'votes' => fn ($query) => $query->where('citizen_id', $user->id)])
            ->loadCount('votes');

        return response()->json([
            'poll' => $this->formatPoll($poll, $user),
        ]);
    }

    public function vote(Request $request, Poll $poll): JsonResponse
    {
        $data = $request->validate([
            'poll_option_id' => ['required', 'integer', 'exists:poll_options,id'],
        ]);

        $user = $request->user();
        $this->closeExpiredPolls();
        $this->syncPollForUser($poll, $user);

        abort_unless($poll->recipients()->where('user_id', $user->id)->exists(), 404);

        if ($poll->status !== 'active' || ! now()->betweenIncluded($poll->starts_at, $poll->ends_at)) {
            return response()->json(['message' => 'This poll is closed.'], 422);
        }

        $option = PollOption::where('poll_id', $poll->id)->findOrFail($data['poll_option_id']);

        $vote = PollVote::firstOrCreate([
            'poll_id' => $poll->id,
            'citizen_id' => $user->id,
        ], [
            'poll_option_id' => $option->id,
        ]);

        if (! $vote->wasRecentlyCreated) {
            return response()->json(['message' => 'You have already voted in this poll.'], 422);
        }

        $poll->load(['options', 'votes' => fn ($query) => $query->where('citizen_id', $user->id)])
            ->loadCount('votes');

        return response()->json([
            'message' => 'Vote saved successfully.',
            'poll' => $this->formatPoll($poll, $user),
        ]);
    }

    private function syncActivePollsForUser(User $user): void
    {
        Poll::where('status', 'active')
            ->where('ends_at', '>=', now())
            ->chunkById(100, function ($polls) use ($user) {
                foreach ($polls as $poll) {
                    $this->syncPollForUser($poll, $user);
                }
            });
    }

    private function syncPollForUser(Poll $poll, User $user): bool
    {
        if ($poll->status !== 'active' || now()->greaterThan($poll->ends_at)) {
            return false;
        }

        if ($poll->recipients()->where('user_id', $user->id)->exists()) {
            return false;
        }

        if ($poll->is_geo_targeted) {
            $homeMatch = $this->targeting->hasPointInsideRadius(
                $user->home_latitude,
                $user->home_longitude,
                (float) $poll->latitude,
                (float) $poll->longitude,
                (int) $poll->radius_meters
            );
            $liveMatch = $user->location_sharing_enabled && $this->targeting->hasPointInsideRadius(
                $user->last_latitude,
                $user->last_longitude,
                (float) $poll->latitude,
                (float) $poll->longitude,
                (int) $poll->radius_meters
            );

            if (! $homeMatch && ! $liveMatch) {
                return false;
            }

            $matchedBy = $homeMatch && $liveMatch ? 'home_and_live' : ($homeMatch ? 'home' : 'live');
        } else {
            $matchedBy = 'general';
        }

        $poll->recipients()->create([
            'user_id' => $user->id,
            'matched_by' => $matchedBy,
        ]);

        return true;
    }

    private function closeExpiredPolls(): void
    {
        Poll::where('status', 'active')
            ->where('ends_at', '<', now())
            ->update(['status' => 'closed']);
    }

    private function formatPoll(Poll $poll, User $user): array
    {
        $selectedVote = $poll->votes->first();
        $showResults = $selectedVote !== null || $poll->status !== 'active';
        $totalVotes = (int) ($poll->votes_count ?? $poll->votes()->count());

        return [
            'id' => $poll->id,
            'question' => $poll->question,
            'poll_type' => $poll->poll_type,
            'status' => $poll->status,
            'starts_at' => $poll->starts_at?->format('Y-m-d\TH:i:s'),
            'ends_at' => $poll->ends_at?->format('Y-m-d\TH:i:s'),
            'is_open' => $poll->status === 'active' && now()->betweenIncluded($poll->starts_at, $poll->ends_at),
            'has_voted' => $selectedVote !== null,
            'selected_option_id' => $selectedVote?->poll_option_id,
            'show_results' => $showResults,
            'total_votes' => $totalVotes,
            'advisory_notice' => 'هذا استطلاع رأي استشاري، ولا يمثل التزاماً تنفيذياً من البلدية.',
            'options' => $poll->options->map(function ($option) use ($showResults, $totalVotes) {
                $votes = $showResults ? $option->votes()->count() : 0;
                return [
                    'id' => $option->id,
                    'option_text' => $option->option_text,
                    'votes_count' => $votes,
                    'percentage' => $showResults && $totalVotes > 0 ? round(($votes / $totalVotes) * 100, 1) : 0,
                ];
            })->values(),
        ];
    }
}
