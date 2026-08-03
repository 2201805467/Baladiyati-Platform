<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\Poll;
use App\Models\User;
use App\Services\GeoBroadcastTargetingService;
use App\Support\SecurityLogger;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\Rule;

class PollController extends Controller
{
    public function __construct(private readonly GeoBroadcastTargetingService $targeting)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $this->closeExpiredPolls();

        $polls = Poll::with('creator:id,full_name,email', 'department:id,dept_name')
            ->withCount(['recipients', 'votes'])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('poll_type'), fn ($query) => $query->where('poll_type', $request->string('poll_type')))
            ->latest()
            ->paginate($request->integer('per_page', 30));

        $polls->getCollection()->transform(fn (Poll $poll) => $this->formatPoll($poll));

        return response()->json($polls);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'question' => ['required', 'string', 'max:255'],
            'poll_type' => ['nullable', Rule::in(['satisfaction', 'budgeting', 'quick'])],
            'options' => ['required', 'array', 'min:2', 'max:4'],
            'options.*' => ['required', 'string', 'max:150'],
            'ends_at' => ['required', 'date', 'after:now'],
            'is_geo_targeted' => ['nullable', 'boolean'],
            'latitude' => ['nullable', 'required_if:is_geo_targeted,true', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'required_if:is_geo_targeted,true', 'numeric', 'between:-180,180'],
            'radius_meters' => ['nullable', 'required_if:is_geo_targeted,true', 'integer', 'min:50', 'max:20000'],
        ]);

        $poll = DB::transaction(function () use ($request, $data) {
            $poll = Poll::create([
                'created_by' => $request->user()->id,
                'dept_id' => $request->user()->dept_id,
                'question' => $data['question'],
                'poll_type' => $data['poll_type'] ?? 'quick',
                'starts_at' => now(),
                'ends_at' => $data['ends_at'],
                'is_geo_targeted' => (bool) ($data['is_geo_targeted'] ?? false),
                'latitude' => $data['latitude'] ?? null,
                'longitude' => $data['longitude'] ?? null,
                'radius_meters' => $data['radius_meters'] ?? null,
                'status' => 'active',
            ]);

            foreach (array_values($data['options']) as $index => $optionText) {
                $poll->options()->create([
                    'option_text' => $optionText,
                    'sort_order' => $index + 1,
                ]);
            }

            $this->notifyTargets($poll);

            return $poll;
        });

        SecurityLogger::log($request, $request->user(), 'poll.created:'.$poll->id, 'success');

        return response()->json([
            'message' => 'Poll created successfully.',
            'poll' => $this->formatPoll($poll->fresh(['options', 'creator'])->loadCount(['recipients', 'votes'])),
        ], 201);
    }

    public function show(Poll $poll): JsonResponse
    {
        $this->closeExpiredPolls();
        $poll->load('creator:id,full_name,email', 'department:id,dept_name', 'options')
            ->loadCount(['recipients', 'votes']);

        return response()->json([
            'poll' => $this->formatPoll($poll, includeResults: true),
        ]);
    }

    public function cancel(Request $request, Poll $poll): JsonResponse
    {
        $data = $request->validate([
            'cancel_reason' => ['required', 'string', 'max:1000'],
        ]);

        if ($poll->status !== 'active') {
            return response()->json(['message' => 'Only active polls can be cancelled.'], 422);
        }

        $poll->update([
            'status' => 'cancelled',
            'cancel_reason' => $data['cancel_reason'],
        ]);

        SecurityLogger::log($request, $request->user(), 'poll.cancelled:'.$poll->id, 'success');

        return response()->json([
            'message' => 'Poll cancelled successfully.',
            'poll' => $this->formatPoll($poll->fresh()->loadCount(['recipients', 'votes'])),
        ]);
    }

    public function destroy(Request $request, Poll $poll): JsonResponse
    {
        $this->closeExpiredPolls();
        $poll->refresh();

        if ($poll->status !== 'closed') {
            return response()->json([
                'message' => 'Only closed polls can be deleted.',
            ], 422);
        }

        $pollId = $poll->id;
        $poll->delete();

        SecurityLogger::log($request, $request->user(), 'poll.deleted:'.$pollId, 'success');

        return response()->json([
            'message' => 'Poll deleted successfully.',
        ]);
    }

    private function notifyTargets(Poll $poll): void
    {
        $citizens = $poll->is_geo_targeted
            ? $this->targeting->targetedCitizens((float) $poll->latitude, (float) $poll->longitude, (int) $poll->radius_meters)
            : User::where('is_active', true)
                ->whereHas('role', fn ($query) => $query->where('role_name', 'citizen'))
                ->get(['id']);

        foreach ($citizens as $citizen) {
            $notification = Notification::create([
                'user_id' => $citizen->id,
                'title' => 'استطلاع رأي جديد',
                'body' => $poll->question,
                'type' => 'poll_opened',
                'related_id' => $poll->id,
                'related_type' => Poll::class,
            ]);

            $poll->recipients()->updateOrCreate(
                ['user_id' => $citizen->id],
                [
                    'matched_by' => $citizen->matched_by ?? 'general',
                    'notification_id' => $notification->id,
                ]
            );
        }
    }

    private function closeExpiredPolls(): void
    {
        Poll::where('status', 'active')
            ->where('ends_at', '<', now())
            ->update(['status' => 'closed']);
    }

    private function formatPoll(Poll $poll, bool $includeResults = false): array
    {
        $totalVotes = (int) ($poll->votes_count ?? $poll->votes()->count());
        $options = $poll->relationLoaded('options') ? $poll->options : $poll->options()->get();

        return [
            ...$poll->toArray(),
            'starts_at' => $poll->starts_at?->format('Y-m-d\TH:i:s'),
            'ends_at' => $poll->ends_at?->format('Y-m-d\TH:i:s'),
            'recipients_count' => (int) ($poll->recipients_count ?? $poll->recipients()->count()),
            'votes_count' => $totalVotes,
            'participation_rate' => $poll->recipients_count
                ? round(($totalVotes / max(1, (int) $poll->recipients_count)) * 100, 1)
                : 0,
            'is_open' => $poll->status === 'active' && now()->betweenIncluded($poll->starts_at, $poll->ends_at),
            'options' => $options->map(function ($option) use ($totalVotes, $includeResults) {
                $votes = $includeResults ? $option->votes()->count() : 0;
                return [
                    'id' => $option->id,
                    'option_text' => $option->option_text,
                    'votes_count' => $votes,
                    'percentage' => $includeResults && $totalVotes > 0 ? round(($votes / $totalVotes) * 100, 1) : 0,
                ];
            })->values(),
        ];
    }
}
