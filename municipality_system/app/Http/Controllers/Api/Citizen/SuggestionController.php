<?php

namespace App\Http\Controllers\Api\Citizen;

use App\Http\Controllers\Controller;
use App\Models\Suggestion;
use App\Models\SuggestionVote;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SuggestionController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $userId = $request->user()->id;

        $suggestions = Suggestion::with(['citizen:id,full_name', 'reviewer:id,full_name'])
            ->withCount([
                'votes as support_votes_count' => fn ($query) => $query->where('vote_type', 'support'),
                'votes as oppose_votes_count' => fn ($query) => $query->where('vote_type', 'oppose'),
            ])
            ->with(['votes' => fn ($query) => $query->where('citizen_id', $userId)])
            ->when($request->boolean('mine'), fn ($query) => $query->where('citizen_id', $userId))
            ->when(
                ! $request->boolean('mine') && ! $request->filled('status'),
                fn ($query) => $query->where('status', 'accepted')
            )
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('category'), fn ($query) => $query->where('category', $request->string('category')))
            ->orderByDesc('support_votes_count')
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return response()->json($suggestions);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'title' => ['required', 'string', 'max:200'],
            'description' => ['required', 'string'],
            'category' => ['nullable', 'string', 'max:100'],
        ]);

        $suggestion = Suggestion::create([
            'citizen_id' => $request->user()->id,
            'title' => $data['title'],
            'description' => $data['description'],
            'category' => $data['category'] ?? null,
            'status' => 'under_review',
        ]);

        return response()->json([
            'message' => 'Suggestion submitted successfully.',
            'suggestion' => $suggestion->load('citizen'),
        ], 201);
    }

    public function update(Request $request, Suggestion $suggestion): JsonResponse
    {
        $this->ensureCitizenOwnsSuggestion($request, $suggestion);
        $this->ensureSuggestionIsEditable($suggestion);

        $data = $request->validate([
            'title' => ['sometimes', 'required', 'string', 'max:200'],
            'description' => ['sometimes', 'required', 'string'],
            'category' => ['nullable', 'string', 'max:100'],
        ]);

        $suggestion->update($data);

        return response()->json([
            'message' => 'Suggestion updated successfully.',
            'suggestion' => $suggestion->fresh()->load('citizen'),
        ]);
    }

    public function destroy(Request $request, Suggestion $suggestion): JsonResponse
    {
        $this->ensureCitizenOwnsSuggestion($request, $suggestion);
        $this->ensureSuggestionIsEditable($suggestion);

        $suggestion->delete();

        return response()->json([
            'message' => 'Suggestion deleted successfully.',
        ]);
    }

    public function vote(Request $request, Suggestion $suggestion): JsonResponse
    {
        $data = $request->validate([
            'vote_type' => ['nullable', Rule::in(['support'])],
        ]);

        if ($suggestion->status !== 'accepted') {
            return response()->json([
                'message' => 'Only accepted suggestions can be voted on.',
            ], 422);
        }

        if ($suggestion->citizen_id === $request->user()->id) {
            return response()->json([
                'message' => 'You cannot vote on your own suggestion.',
            ], 422);
        }

        $vote = SuggestionVote::updateOrCreate(
            [
                'suggestion_id' => $suggestion->id,
                'citizen_id' => $request->user()->id,
            ],
            [
                'vote_type' => $data['vote_type'] ?? 'support',
            ]
        );

        return response()->json([
            'message' => 'Vote saved successfully.',
            'vote' => $vote,
        ]);
    }

    public function destroyVote(Request $request, Suggestion $suggestion): JsonResponse
    {
        SuggestionVote::where('suggestion_id', $suggestion->id)
            ->where('citizen_id', $request->user()->id)
            ->delete();

        return response()->json([
            'message' => 'Vote cancelled successfully.',
        ]);
    }

    private function ensureCitizenOwnsSuggestion(Request $request, Suggestion $suggestion): void
    {
        if ($suggestion->citizen_id !== $request->user()->id) {
            throw new AuthorizationException('This suggestion does not belong to the authenticated citizen.');
        }
    }

    private function ensureSuggestionIsEditable(Suggestion $suggestion): void
    {
        if ($suggestion->status !== 'under_review') {
            abort(422, 'Only suggestions under review can be edited or deleted.');
        }
    }
}
