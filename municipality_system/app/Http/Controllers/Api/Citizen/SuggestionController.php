<?php

namespace App\Http\Controllers\Api\Citizen;

use App\Http\Controllers\Controller;
use App\Models\Suggestion;
use App\Models\SuggestionVote;
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
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('category'), fn ($query) => $query->where('category', $request->string('category')))
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

    public function vote(Request $request, Suggestion $suggestion): JsonResponse
    {
        $data = $request->validate([
            'vote_type' => ['required', Rule::in(['support', 'oppose'])],
        ]);

        $vote = SuggestionVote::updateOrCreate(
            [
                'suggestion_id' => $suggestion->id,
                'citizen_id' => $request->user()->id,
            ],
            [
                'vote_type' => $data['vote_type'],
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
}
