<?php

namespace App\Http\Controllers\Api\Citizen;

use App\Http\Controllers\Controller;
use App\Http\Controllers\Api\Concerns\FormatsMunicipalityChats;
use App\Models\MunicipalityChatThread;
use Illuminate\Http\Request;

class MunicipalityChatController extends Controller
{
    use FormatsMunicipalityChats;

    public function show(Request $request)
    {
        $thread = $this->threadForCitizen($request);
        $thread->forceFill(['citizen_unread_count' => 0])->save();

        return response()->json([
            'thread' => $this->formatThread($thread->fresh(), $request->user()),
            'outside_working_hours' => $this->isOutsideWorkingHours(),
        ]);
    }

    public function sendMessage(Request $request)
    {
        $validated = $request->validate([
            'message_text' => ['nullable', 'string', 'max:2000', 'required_without_all:image,latitude,longitude'],
            'image' => ['nullable', 'image', 'max:5120'],
            'latitude' => ['nullable', 'numeric', 'between:-90,90'],
            'longitude' => ['nullable', 'numeric', 'between:-180,180'],
        ]);

        $thread = $this->threadForCitizen($request);
        $imageUrl = $request->hasFile('image') ? $this->storeChatImage($request->file('image')) : null;

        $thread->messages()->create([
            'sender_id' => $request->user()->id,
            'sender_role' => 'citizen',
            'message_text' => $validated['message_text'] ?? null,
            'image_url' => $imageUrl,
            'latitude' => $validated['latitude'] ?? null,
            'longitude' => $validated['longitude'] ?? null,
        ]);
        $this->addOutsideWorkingHoursMessageIfNeeded($thread);

        $thread->forceFill([
            'status' => $thread->status === 'closed' ? 'active' : ($thread->status === 'new' ? 'new' : 'active'),
            'last_message_at' => now(),
            'closed_at' => null,
            'reception_unread_count' => $thread->assigned_dept_id ? $thread->reception_unread_count : $thread->reception_unread_count + 1,
            'department_unread_count' => $thread->assigned_dept_id ? $thread->department_unread_count + 1 : $thread->department_unread_count,
        ])->save();

        $body = 'وصلت رسالة جديدة من مواطن في خدمة العملاء.';
        if ($thread->assigned_dept_id) {
            $this->notifyUsers(
                $this->departmentUsers($thread->assigned_dept_id),
                'رسالة جديدة من مواطن',
                $body,
                $thread
            );
        } else {
            $this->notifyUsers($this->receptionUsers(), 'رسالة جديدة من مواطن', $body, $thread);
        }

        return response()->json([
            'message' => 'تم إرسال الرسالة بنجاح.',
            'thread' => $this->formatThread($thread->fresh(), $request->user()),
            'outside_working_hours' => $this->isOutsideWorkingHours(),
        ], 201);
    }

    private function threadForCitizen(Request $request): MunicipalityChatThread
    {
        $this->pruneExpiredClosedThreads($request->user());

        $thread = MunicipalityChatThread::firstOrCreate(
            ['citizen_id' => $request->user()->id],
            ['status' => 'new', 'last_message_at' => now()]
        );

        $this->ensureWelcomeMessage($thread);

        return $thread;
    }
}
