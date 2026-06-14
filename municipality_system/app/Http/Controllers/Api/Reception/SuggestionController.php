<?php

namespace App\Http\Controllers\Api\Reception;

use App\Http\Controllers\Controller;
use App\Models\Notification;
use App\Models\Suggestion;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\Rule;

class SuggestionController extends Controller
{
    public function index(Request $request): JsonResponse
    {
        $suggestions = Suggestion::with(['citizen:id,full_name', 'reviewer:id,full_name'])
            ->withCount([
                'votes as support_votes_count' => fn ($query) => $query->where('vote_type', 'support'),
                'votes as oppose_votes_count' => fn ($query) => $query->where('vote_type', 'oppose'),
            ])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('category'), fn ($query) => $query->where('category', $request->string('category')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = '%'.$request->string('search')->toString().'%';

                $query->where(function ($query) use ($search) {
                    $query->where('title', 'like', $search)
                        ->orWhere('description', 'like', $search);
                });
            })
            ->latest()
            ->paginate($request->integer('per_page', 15));

        return response()->json($suggestions);
    }

    public function accept(Request $request, Suggestion $suggestion): JsonResponse
    {
        $suggestion->update([
            'status' => 'accepted',
            'rejection_reason' => null,
            'reviewed_by' => $request->user()->id,
        ]);

        $this->notifyCitizen(
            $suggestion,
            'Suggestion accepted',
            'Your suggestion "'.$suggestion->title.'" was accepted.',
            'suggestion_status'
        );

        return response()->json([
            'message' => 'Suggestion accepted successfully.',
            'suggestion' => $suggestion->fresh()->load(['citizen', 'reviewer']),
        ]);
    }

    public function reject(Request $request, Suggestion $suggestion): JsonResponse
    {
        $data = $request->validate([
            'rejection_reason' => ['required', 'string', 'max:2000'],
        ]);

        $suggestion->update([
            'status' => 'rejected',
            'rejection_reason' => $data['rejection_reason'],
            'reviewed_by' => $request->user()->id,
        ]);

        $this->notifyCitizen(
            $suggestion,
            'Suggestion rejected',
            'Your suggestion "'.$suggestion->title.'" was rejected: '.$data['rejection_reason'],
            'suggestion_status'
        );

        return response()->json([
            'message' => 'Suggestion rejected successfully.',
            'suggestion' => $suggestion->fresh()->load(['citizen', 'reviewer']),
        ]);
    }

    public function updateImplementation(Request $request, Suggestion $suggestion): JsonResponse
    {
        if ($suggestion->status !== 'accepted') {
            return response()->json([
                'message' => 'Only accepted suggestions can have implementation progress.',
            ], 422);
        }

        $data = $request->validate([
            'implementation_status' => ['required', Rule::in(['planned', 'in_progress', 'completed', 'paused', 'cancelled'])],
            'implementation_progress_percent' => ['required', 'integer', 'min:0', 'max:100'],
            'implementation_note' => ['nullable', 'string', 'max:2000'],
        ]);

        if ($data['implementation_status'] === 'completed' && $data['implementation_progress_percent'] < 100) {
            return response()->json([
                'message' => 'Completed suggestions must have 100% progress.',
            ], 422);
        }

        $suggestion->update($data);

        $this->notifyCitizen(
            $suggestion,
            'Suggestion implementation updated',
            'Implementation progress for "'.$suggestion->title.'" is now '.$data['implementation_progress_percent'].'%.',
            'suggestion_implementation'
        );

        return response()->json([
            'message' => 'Suggestion implementation updated successfully.',
            'suggestion' => $suggestion->fresh()->load(['citizen', 'reviewer']),
        ]);
    }

    private function notifyCitizen(Suggestion $suggestion, string $title, string $body, string $type): void
    {
        Notification::create([
            'user_id' => $suggestion->citizen_id,
            'title' => $title,
            'body' => $body,
            'type' => $type,
            'related_id' => $suggestion->id,
            'related_type' => Suggestion::class,
        ]);
    }
}
