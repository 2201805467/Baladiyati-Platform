<?php

namespace App\Http\Controllers\Api\Admin;

use App\Http\Controllers\Controller;
use App\Models\CommunityInitiative;
use App\Models\Notification;
use App\Models\Role;
use App\Models\User;
use App\Services\InitiativeVolunteerBlocker;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class CommunityInitiativeController extends Controller
{
    public function __construct(private readonly InitiativeVolunteerBlocker $volunteerBlocker)
    {
    }

    public function index(Request $request): JsonResponse
    {
        $initiatives = CommunityInitiative::with('creator:id,full_name,email')
            ->withCount([
                'registrations as registered_count' => fn ($query) => $query->where('status', 'registered'),
                'attendees as attendees_count',
            ])
            ->when($request->filled('status'), fn ($query) => $query->where('status', $request->string('status')))
            ->when($request->filled('initiative_type'), fn ($query) => $query->where('initiative_type', $request->string('initiative_type')))
            ->when($request->filled('search'), function ($query) use ($request) {
                $search = '%'.$request->string('search')->toString().'%';

                $query->where(fn ($query) => $query
                    ->where('title', 'like', $search)
                    ->orWhere('description', 'like', $search)
                    ->orWhere('goal', 'like', $search));
            })
            ->orderByDesc('starts_at')
            ->paginate($request->integer('per_page', 15));

        $initiatives->getCollection()->transform(fn (CommunityInitiative $initiative) => $this->formatInitiative($initiative));

        return response()->json($initiatives);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'title' => ['required', 'string', 'max:200'],
            'description' => ['required', 'string'],
            'goal' => ['nullable', 'string'],
            'initiative_type' => ['required', Rule::in(['tree_planting', 'cleaning', 'painting', 'awareness', 'other'])],
            'cover_image' => ['nullable', 'image', 'max:5120'],
            'starts_at' => ['required', 'date'],
            'ends_at' => ['required', 'date', 'after:starts_at'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'radius_meters' => ['nullable', 'integer', 'min:20', 'max:5000'],
            'max_capacity' => ['nullable', 'integer', 'min:1', 'max:100000'],
            'target_audience' => ['nullable', 'string', 'max:100'],
            'requirements' => ['nullable', 'string'],
            'status' => ['nullable', Rule::in(['published', 'registration_closed'])],
        ]);

        $coverImageUrl = null;
        if ($request->hasFile('cover_image')) {
            $coverImageUrl = Storage::url($request->file('cover_image')->store('initiatives/covers', 'public'));
        }
        unset($data['cover_image']);

        $initiative = CommunityInitiative::create([
            ...$data,
            'cover_image_url' => $coverImageUrl,
            'radius_meters' => $data['radius_meters'] ?? 100,
            'status' => $data['status'] ?? 'published',
            'created_by' => $request->user()->id,
        ]);

        if ($initiative->status === 'published') {
            $this->notifyCitizens(
                'تم فتح مبادرة جديدة',
                'مبادرة جديدة: '.$initiative->title.'، سجل الآن.',
                'initiative_published',
                $initiative->id
            );
        }

        return response()->json([
            'message' => 'Community initiative created successfully.',
            'initiative' => $this->formatInitiative($initiative->fresh()->load('creator:id,full_name,email')),
        ], 201);
    }

    public function show(CommunityInitiative $initiative): JsonResponse
    {
        $initiative->load([
            'creator:id,full_name,email',
            'registrations.citizen:id,full_name,email,phone',
        ])->loadCount([
            'registrations as registered_count' => fn ($query) => $query->where('status', 'registered'),
            'attendees as attendees_count',
        ]);

        return response()->json([
            'initiative' => $this->formatInitiative($initiative),
            'registrations' => $initiative->registrations
                ->where('status', 'registered')
                ->values()
                ->map(fn ($registration) => $this->formatRegistration($registration)),
            'attendees' => $initiative->registrations
                ->filter(fn ($registration) => $registration->attended_at !== null)
                ->values()
                ->map(fn ($registration) => $this->formatRegistration($registration)),
        ]);
    }

    public function closeRegistration(CommunityInitiative $initiative): JsonResponse
    {
        if (! in_array($initiative->status, ['published', 'registration_closed'], true)) {
            return response()->json(['message' => 'Registration can be closed only for active initiatives.'], 422);
        }

        $initiative->update(['status' => 'registration_closed']);

        return response()->json([
            'message' => 'Initiative registration closed successfully.',
            'initiative' => $this->formatInitiative($initiative->fresh()),
        ]);
    }

    public function publish(CommunityInitiative $initiative): JsonResponse
    {
        if (! in_array($initiative->status, ['registration_closed'], true)) {
            return response()->json(['message' => 'Only closed registration initiatives can be published again.'], 422);
        }

        $initiative->update(['status' => 'published']);

        return response()->json([
            'message' => 'Initiative published successfully.',
            'initiative' => $this->formatInitiative($initiative->fresh()),
        ]);
    }

    public function cancel(Request $request, CommunityInitiative $initiative): JsonResponse
    {
        $data = $request->validate([
            'cancel_reason' => ['required', 'string', 'max:1000'],
        ]);

        if ($initiative->status === 'completed') {
            return response()->json(['message' => 'Completed initiatives cannot be cancelled.'], 422);
        }

        $initiative->update([
            'status' => 'cancelled',
            'cancel_reason' => $data['cancel_reason'],
        ]);

        $this->notifyRegisteredCitizens(
            $initiative,
            'تم إلغاء المبادرة',
            'تم إلغاء مبادرة '.$initiative->title.'. السبب: '.$data['cancel_reason'],
            'initiative_cancelled'
        );

        return response()->json([
            'message' => 'Initiative cancelled successfully.',
            'initiative' => $this->formatInitiative($initiative->fresh()),
        ]);
    }

    public function complete(Request $request, CommunityInitiative $initiative): JsonResponse
    {
        $data = $request->validate([
            'completion_image' => ['nullable', 'image', 'max:5120'],
        ]);

        if ($initiative->status === 'cancelled') {
            return response()->json(['message' => 'Cancelled initiatives cannot be completed.'], 422);
        }

        $completionImageUrl = $initiative->completion_image_url;
        if ($request->hasFile('completion_image')) {
            $completionImageUrl = Storage::url($request->file('completion_image')->store('initiatives/completions', 'public'));
        }

        $initiative->update([
            'status' => 'completed',
            'completion_image_url' => $completionImageUrl,
        ]);

        $this->notifyAttendees(
            $initiative,
            'شكراً لمشاركتكم',
            'شكراً لمشاركتكم في '.$initiative->title.'! تم إنجاز الحملة بنجاح.',
            'initiative_completed'
        );

        $this->volunteerBlocker->refreshAllCitizens();

        return response()->json([
            'message' => 'Initiative completed successfully.',
            'initiative' => $this->formatInitiative($initiative->fresh()),
        ]);
    }

    public function destroy(CommunityInitiative $initiative): JsonResponse
    {
        if (! in_array($initiative->status, ['completed', 'cancelled'], true)) {
            return response()->json([
                'message' => 'Only completed or cancelled initiatives can be deleted.',
            ], 422);
        }

        $this->deletePublicStorageFile($initiative->cover_image_url);
        $this->deletePublicStorageFile($initiative->completion_image_url);
        $initiative->delete();

        return response()->json([
            'message' => 'Initiative deleted successfully.',
        ]);
    }

    public function blockedCitizens(Request $request): JsonResponse
    {
        $this->volunteerBlocker->refreshAllCitizens();

        $citizenRoleId = Role::where('role_name', 'citizen')->value('id');

        $citizens = User::query()
            ->when($citizenRoleId, fn ($query) => $query->where('role_id', $citizenRoleId))
            ->whereNotNull('initiative_registration_blocked_at')
            ->orderByDesc('initiative_registration_blocked_at')
            ->paginate($request->integer('per_page', 50));

        $citizens->getCollection()->transform(fn (User $citizen) => $this->formatBlockedCitizen($citizen));

        return response()->json($citizens);
    }

    public function unblockCitizen(User $citizen): JsonResponse
    {
        $citizen->update([
            'initiative_registration_blocked_at' => null,
            'initiative_registration_unblocked_at' => now(),
            'initiative_registration_block_reason' => null,
        ]);

        return response()->json([
            'message' => 'Citizen initiative registration block removed successfully.',
            'citizen' => $this->formatBlockedCitizen($citizen->fresh()),
        ]);
    }

    private function notifyCitizens(string $title, string $body, string $type, int $initiativeId): void
    {
        $citizenRoleId = Role::where('role_name', 'citizen')->value('id');
        if (! $citizenRoleId) {
            return;
        }

        User::where('role_id', $citizenRoleId)
            ->where('is_active', true)
            ->select('id')
            ->chunkById(100, function ($citizens) use ($title, $body, $type, $initiativeId) {
                foreach ($citizens as $citizen) {
                    Notification::create([
                        'user_id' => $citizen->id,
                        'title' => $title,
                        'body' => $body,
                        'type' => $type,
                        'related_id' => $initiativeId,
                        'related_type' => CommunityInitiative::class,
                    ]);
                }
            });
    }

    private function notifyRegisteredCitizens(CommunityInitiative $initiative, string $title, string $body, string $type): void
    {
        $initiative->registrations()
            ->where('status', 'registered')
            ->whereNotNull('citizen_id')
            ->select('id', 'citizen_id')
            ->chunkById(100, function ($registrations) use ($title, $body, $type, $initiative) {
                foreach ($registrations as $registration) {
                    Notification::create([
                        'user_id' => $registration->citizen_id,
                        'title' => $title,
                        'body' => $body,
                        'type' => $type,
                        'related_id' => $initiative->id,
                        'related_type' => CommunityInitiative::class,
                    ]);
                }
            });
    }

    private function notifyAttendees(CommunityInitiative $initiative, string $title, string $body, string $type): void
    {
        $initiative->registrations()
            ->whereNotNull('attended_at')
            ->whereNotNull('citizen_id')
            ->select('id', 'citizen_id')
            ->chunkById(100, function ($registrations) use ($title, $body, $type, $initiative) {
                foreach ($registrations as $registration) {
                    Notification::create([
                        'user_id' => $registration->citizen_id,
                        'title' => $title,
                        'body' => $body,
                        'type' => $type,
                        'related_id' => $initiative->id,
                        'related_type' => CommunityInitiative::class,
                    ]);
                }
            });
    }

    private function formatInitiative(CommunityInitiative $initiative): array
    {
        $registeredCount = (int) ($initiative->registered_count ?? $initiative->activeRegistrations()->count());
        $maxCapacity = $initiative->max_capacity;

        return [
            ...$initiative->toArray(),
            'starts_at' => $initiative->starts_at?->format('Y-m-d\TH:i:s'),
            'ends_at' => $initiative->ends_at?->format('Y-m-d\TH:i:s'),
            'registered_count' => $registeredCount,
            'attendees_count' => (int) ($initiative->attendees_count ?? $initiative->attendees()->count()),
            'is_full' => $maxCapacity !== null && $registeredCount >= $maxCapacity,
            'available_slots' => $maxCapacity === null ? null : max(0, $maxCapacity - $registeredCount),
        ];
    }

    private function formatRegistration($registration): array
    {
        return [
            'id' => $registration->id,
            'status' => $registration->status,
            'registered_at' => $registration->registered_at,
            'cancelled_at' => $registration->cancelled_at,
            'attended_at' => $registration->attended_at,
            'citizen' => $registration->citizen,
        ];
    }

    private function formatBlockedCitizen(User $citizen): array
    {
        return [
            'id' => $citizen->id,
            'full_name' => $citizen->full_name,
            'email' => $citizen->email,
            'phone' => $citizen->phone,
            'blocked_at' => $citizen->initiative_registration_blocked_at,
            'block_reason' => $citizen->initiative_registration_block_reason,
            'missed_completed_initiatives_count' => $this->volunteerBlocker->missedCompletedInitiativesCount($citizen),
            'attended_completed_initiatives_count' => $this->volunteerBlocker->attendedCompletedInitiativesCount($citizen),
        ];
    }

    private function deletePublicStorageFile(?string $url): void
    {
        if (! $url || ! str_starts_with($url, '/storage/')) {
            return;
        }

        Storage::disk('public')->delete(substr($url, strlen('/storage/')));
    }
}
