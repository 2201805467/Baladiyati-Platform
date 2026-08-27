<?php

namespace App\Http\Controllers\Api\Citizen;

use App\Http\Controllers\Controller;
use App\Models\LostFoundAbuseReport;
use App\Models\LostFoundChatMessage;
use App\Models\LostFoundChatThread;
use App\Models\LostFoundComment;
use App\Models\LostFoundItem;
use App\Models\Notification;
use App\Models\User;
use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;

class LostFoundController extends Controller
{
    private const CATEGORIES = ['keys', 'documents', 'pet', 'electronics', 'wallet_money', 'other'];

    public function index(Request $request): JsonResponse
    {
        $data = $request->validate([
            'item_type' => ['nullable', Rule::in(['lost', 'found'])],
            'category' => ['nullable', Rule::in(self::CATEGORIES)],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
            'radius_km' => ['nullable', 'numeric', 'min:0.1', 'max:50'],
            'per_page' => ['nullable', 'integer', 'min:1', 'max:50'],
        ]);

        $this->expireOldItems();

        $latitude = isset($data['latitude']) ? (float) $data['latitude'] : null;
        $longitude = isset($data['longitude']) ? (float) $data['longitude'] : null;
        $radiusKm = isset($data['radius_km']) ? (float) $data['radius_km'] : null;

        $query = LostFoundItem::query()
            ->withCount(['comments', 'chatThreads'])
            ->where('status', 'active')
            ->when(isset($data['item_type']), fn ($query) => $query->where('item_type', $data['item_type']))
            ->when(isset($data['category']), fn ($query) => $query->where('category', $data['category']));

        if ($latitude !== null && $longitude !== null) {
            $query
                ->select('lost_found_items.*')
                ->selectRaw(
                    '(6371 * acos(least(1, greatest(-1, cos(radians(?)) * cos(radians(latitude)) * cos(radians(longitude) - radians(?)) + sin(radians(?)) * sin(radians(latitude)))))) as distance_km',
                    [$latitude, $longitude, $latitude]
                )
                ->when($radiusKm !== null, fn ($query) => $query->having('distance_km', '<=', $radiusKm))
                ->orderBy('distance_km');
        } else {
            $query->latest();
        }

        $items = $query->paginate($request->integer('per_page', 15));
        $items->getCollection()->transform(fn (LostFoundItem $item) => $this->formatItem($item, $request->user()->id));

        return response()->json($items);
    }

    public function myItems(Request $request): JsonResponse
    {
        $this->expireOldItems();

        $items = LostFoundItem::where('user_id', $request->user()->id)
            ->withCount(['comments', 'chatThreads'])
            ->latest()
            ->paginate($request->integer('per_page', 30));

        $items->getCollection()->transform(fn (LostFoundItem $item) => $this->formatItem($item, $request->user()->id));

        return response()->json($items);
    }

    public function store(Request $request): JsonResponse
    {
        $data = $request->validate([
            'item_type' => ['required', Rule::in(['lost', 'found'])],
            'category' => ['required', Rule::in(self::CATEGORIES)],
            'title' => ['required', 'string', 'max:200'],
            'description' => ['required', 'string', 'max:3000'],
            'image' => [Rule::requiredIf($request->input('item_type') === 'found'), 'nullable', 'image', 'max:5120'],
            'latitude' => ['required', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'numeric', 'between:-180,180'],
            'area_name' => ['nullable', 'string', 'max:150'],
            'incident_date' => ['nullable', 'date'],
            'pet_type' => ['nullable', 'string', 'max:100'],
            'pet_identifying_marks' => ['nullable', 'string', 'max:1000'],
            'pet_has_collar' => ['nullable', 'boolean'],
        ]);

        $imageUrl = null;
        if ($request->hasFile('image')) {
            $imageUrl = Storage::url($request->file('image')->store('lost-found/items', 'public'));
        }

        $item = LostFoundItem::create([
            ...collect($data)->except('image')->all(),
            'user_id' => $request->user()->id,
            'image_url' => $imageUrl,
            'status' => 'active',
            'expires_at' => now()->addDays(30),
        ]);

        return response()->json([
            'message' => 'Lost and found item published successfully.',
            'item' => $this->formatItem($item->fresh()->loadCount(['comments', 'chatThreads']), $request->user()->id),
            'documents_warning' => $item->category === 'documents'
                ? 'يرجى أيضاً التبليغ عن الوثائق الرسمية لدى الجهات المختصة. التطبيق مكمل وليس بديلاً عن الإجراء الرسمي.'
                : null,
        ], 201);
    }

    public function show(Request $request, LostFoundItem $item): JsonResponse
    {
        $this->expireOldItems();
        $this->ensureItemCanBeViewed($request, $item);

        $item->load(['comments.user:id'])
            ->loadCount(['comments', 'chatThreads']);

        return response()->json([
            'item' => $this->formatItem($item, $request->user()->id, includeComments: true),
        ]);
    }

    public function storeComment(Request $request, LostFoundItem $item): JsonResponse
    {
        $this->ensureItemVisible($item);

        $data = $request->validate([
            'comment_text' => ['required', 'string', 'max:2000'],
        ]);

        $comment = LostFoundComment::create([
            'lost_found_item_id' => $item->id,
            'user_id' => $request->user()->id,
            'comment_text' => $data['comment_text'],
        ]);

        if ($item->user_id && $item->user_id !== $request->user()->id) {
            Notification::create([
                'user_id' => $item->user_id,
                'title' => 'تعليق جديد على منشورك',
                'body' => 'قام مواطن بإضافة تعليق على منشور '.$item->title.'.',
                'type' => 'lost_found_comment',
                'related_id' => $item->id,
                'related_type' => LostFoundItem::class,
            ]);
        }

        return response()->json([
            'message' => 'Comment added successfully.',
            'comment' => $this->formatComment($comment, $request->user()->id, $item->user_id),
        ], 201);
    }

    public function resolve(Request $request, LostFoundItem $item): JsonResponse
    {
        $this->ensureOwner($request, $item);

        if ($item->status !== 'active') {
            return response()->json(['message' => 'Only active posts can be marked as resolved.'], 422);
        }

        $item->update([
            'status' => 'resolved',
            'resolved_at' => now(),
        ]);

        $this->notifyThreadParticipants($item, 'تم حل منشور مفقودات وموجودات', 'تم تحديث حالة المنشور '.$item->title.' إلى تم الحل.');

        return response()->json([
            'message' => 'Item marked as resolved successfully.',
            'item' => $this->formatItem($item->fresh()->loadCount(['comments', 'chatThreads']), $request->user()->id),
        ]);
    }

    public function republish(Request $request, LostFoundItem $item): JsonResponse
    {
        $this->ensureOwner($request, $item);

        if ($item->status !== 'expired') {
            return response()->json(['message' => 'Only expired posts can be republished.'], 422);
        }

        $item->update([
            'status' => 'active',
            'expires_at' => now()->addDays(30),
        ]);

        return response()->json([
            'message' => 'Item republished successfully.',
            'item' => $this->formatItem($item->fresh()->loadCount(['comments', 'chatThreads']), $request->user()->id),
        ]);
    }

    public function startThread(Request $request, LostFoundItem $item): JsonResponse
    {
        $this->ensureItemVisible($item);

        if ($item->user_id === $request->user()->id) {
            return response()->json(['message' => 'You cannot start a private chat with yourself.'], 422);
        }

        $thread = LostFoundChatThread::firstOrCreate(
            [
                'lost_found_item_id' => $item->id,
                'interested_user_id' => $request->user()->id,
            ],
            [
                'publisher_id' => $item->user_id,
                'status' => 'open',
            ]
        );

        return response()->json([
            'message' => 'Chat thread ready.',
            'thread' => $this->formatThread($thread->fresh()->load(['item', 'messages']), $request->user()->id),
        ]);
    }

    public function threads(Request $request): JsonResponse
    {
        $threads = LostFoundChatThread::with(['item', 'messages' => fn ($query) => $query->latest()->limit(1)])
            ->where(fn ($query) => $query
                ->where('publisher_id', $request->user()->id)
                ->orWhere('interested_user_id', $request->user()->id))
            ->latest('updated_at')
            ->paginate($request->integer('per_page', 30));

        $threads->getCollection()->transform(fn (LostFoundChatThread $thread) => $this->formatThread($thread, $request->user()->id));

        return response()->json($threads);
    }

    public function showThread(Request $request, LostFoundChatThread $thread): JsonResponse
    {
        $this->ensureThreadParticipant($request, $thread);

        $thread->load(['item', 'messages']);

        return response()->json([
            'thread' => $this->formatThread($thread, $request->user()->id, includeMessages: true),
        ]);
    }

    public function storeMessage(Request $request, LostFoundChatThread $thread): JsonResponse
    {
        $this->ensureThreadParticipant($request, $thread);

        $data = $request->validate([
            'message_text' => ['required', 'string', 'max:3000'],
        ]);

        $message = LostFoundChatMessage::create([
            'lost_found_chat_thread_id' => $thread->id,
            'sender_id' => $request->user()->id,
            'message_text' => $data['message_text'],
        ]);
        $thread->touch();

        $recipientId = $thread->publisher_id === $request->user()->id
            ? $thread->interested_user_id
            : $thread->publisher_id;

        if ($recipientId) {
            Notification::create([
                'user_id' => $recipientId,
                'title' => 'رسالة جديدة في المفقودات والموجودات',
                'body' => 'وصلتك رسالة جديدة بخصوص '.$thread->item?->title.'.',
                'type' => 'lost_found_chat_message',
                'related_id' => $thread->id,
                'related_type' => LostFoundChatThread::class,
            ]);
        }

        return response()->json([
            'message' => 'Message sent successfully.',
            'chat_message' => $this->formatMessage($message, $request->user()->id),
        ], 201);
    }

    public function reportAbuse(Request $request): JsonResponse
    {
        $data = $request->validate([
            'reportable_type' => ['required', Rule::in(['item', 'message'])],
            'reportable_id' => ['required', 'integer'],
            'reason' => ['required', 'string', 'max:2000'],
        ]);

        $reportableClass = $data['reportable_type'] === 'item'
            ? LostFoundItem::class
            : LostFoundChatMessage::class;

        if ($reportableClass === LostFoundItem::class) {
            $item = LostFoundItem::findOrFail($data['reportable_id']);

            if ($item->user_id === $request->user()->id) {
                throw new AuthorizationException('You cannot report your own post.');
            }
        } else {
            $message = LostFoundChatMessage::with('thread')->findOrFail($data['reportable_id']);
            $this->ensureThreadParticipant($request, $message->thread);

            if ($message->sender_id === $request->user()->id) {
                throw new AuthorizationException('You cannot report your own message.');
            }
        }

        $report = LostFoundAbuseReport::create([
            'reporter_id' => $request->user()->id,
            'reportable_type' => $reportableClass,
            'reportable_id' => $data['reportable_id'],
            'reason' => $data['reason'],
            'status' => 'pending',
        ]);

        User::where('is_active', true)
            ->whereHas('role', fn ($query) => $query->whereIn('role_name', ['admin', 'reception']))
            ->get(['id'])
            ->each(function (User $moderator) use ($report) {
                Notification::create([
                    'user_id' => $moderator->id,
                    'title' => 'بلاغ إساءة في المفقودات والموجودات',
                    'body' => 'وصل بلاغ إساءة جديد يحتاج مراجعة المشرف.',
                    'type' => 'lost_found_abuse_report',
                    'related_id' => $report->id,
                    'related_type' => LostFoundAbuseReport::class,
                ]);
            });

        return response()->json([
            'message' => 'Report submitted successfully.',
            'abuse_report' => $report,
        ], 201);
    }

    private function ensureOwner(Request $request, LostFoundItem $item): void
    {
        if ($item->user_id !== $request->user()->id) {
            throw new AuthorizationException('Only the publisher can update this post.');
        }
    }

    private function ensureItemVisible(LostFoundItem $item): void
    {
        if ($item->status !== 'active') {
            throw new AuthorizationException('This post is not active.');
        }
    }

    private function ensureItemCanBeViewed(Request $request, LostFoundItem $item): void
    {
        if ($item->status === 'removed') {
            throw new AuthorizationException('This post is not available.');
        }

        if ($item->status !== 'active' && $item->user_id !== $request->user()->id) {
            throw new AuthorizationException('This post is not active.');
        }
    }

    private function ensureThreadParticipant(Request $request, LostFoundChatThread $thread): void
    {
        if (! in_array($request->user()->id, [$thread->publisher_id, $thread->interested_user_id], true)) {
            throw new AuthorizationException('This chat does not belong to the authenticated user.');
        }
    }

    private function expireOldItems(): void
    {
        LostFoundItem::where('status', 'active')
            ->whereNotNull('expires_at')
            ->where('expires_at', '<', now())
            ->update(['status' => 'expired']);
    }

    private function notifyThreadParticipants(LostFoundItem $item, string $title, string $body): void
    {
        $item->chatThreads()
            ->select('id', 'publisher_id', 'interested_user_id')
            ->chunkById(100, function ($threads) use ($item, $title, $body) {
                foreach ($threads as $thread) {
                    foreach (array_filter([$thread->publisher_id, $thread->interested_user_id]) as $userId) {
                        Notification::create([
                            'user_id' => $userId,
                            'title' => $title,
                            'body' => $body,
                            'type' => 'lost_found_status_changed',
                            'related_id' => $item->id,
                            'related_type' => LostFoundItem::class,
                        ]);
                    }
                }
            });
    }

    private function formatItem(LostFoundItem $item, int $viewerId, bool $includeComments = false): array
    {
        $payload = [
            ...$item->toArray(),
            'incident_date' => $item->incident_date?->format('Y-m-d'),
            'expires_at' => $item->expires_at?->format('Y-m-d\TH:i:s'),
            'resolved_at' => $item->resolved_at?->format('Y-m-d\TH:i:s'),
            'comments_count' => (int) ($item->comments_count ?? $item->comments()->count()),
            'threads_count' => (int) ($item->chat_threads_count ?? $item->chatThreads()->count()),
            'distance_km' => isset($item->distance_km) ? round((float) $item->distance_km, 2) : null,
            'is_owner' => $item->user_id === $viewerId,
            'publisher_alias' => $item->user_id === $viewerId ? 'الناشر' : 'مواطن ناشر',
        ];

        if ($includeComments) {
            $payload['comments'] = $item->comments
                ->map(fn (LostFoundComment $comment) => $this->formatComment($comment, $viewerId, $item->user_id))
                ->values();
        }

        return $payload;
    }

    private function formatComment(LostFoundComment $comment, int $viewerId, ?int $publisherId): array
    {
        return [
            'id' => $comment->id,
            'comment_text' => $comment->comment_text,
            'author_alias' => $comment->user_id === $publisherId
                ? 'الناشر'
                : ($comment->user_id === $viewerId ? 'أنت' : 'مواطن'),
            'created_at' => $comment->created_at,
        ];
    }

    private function formatThread(LostFoundChatThread $thread, int $viewerId, bool $includeMessages = false): array
    {
        $isPublisher = $thread->publisher_id === $viewerId;
        $payload = [
            'id' => $thread->id,
            'item_id' => $thread->lost_found_item_id,
            'item_title' => $thread->item?->title,
            'item_type' => $thread->item?->item_type,
            'status' => $thread->status,
            'viewer_alias' => $isPublisher ? 'الناشر' : 'مستخدم مهتم',
            'other_alias' => $isPublisher ? 'مستخدم مهتم' : 'الناشر',
            'last_message' => $thread->messages->first()?->message_text,
            'updated_at' => $thread->updated_at,
        ];

        if ($includeMessages) {
            $payload['messages'] = $thread->messages
                ->map(fn (LostFoundChatMessage $message) => $this->formatMessage($message, $viewerId))
                ->values();
        }

        return $payload;
    }

    private function formatMessage(LostFoundChatMessage $message, int $viewerId): array
    {
        return [
            'id' => $message->id,
            'message_text' => $message->message_text,
            'is_mine' => $message->sender_id === $viewerId,
            'sender_alias' => $message->sender_id === $viewerId ? 'أنت' : 'الطرف الآخر',
            'created_at' => $message->created_at,
        ];
    }
}
