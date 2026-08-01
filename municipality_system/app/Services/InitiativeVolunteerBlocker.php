<?php

namespace App\Services;

use App\Models\Role;
use App\Models\User;

class InitiativeVolunteerBlocker
{
    private const MISSED_ATTENDANCE_LIMIT = 3;

    public function refreshUser(User $user): User
    {
        if ($user->initiative_registration_blocked_at) {
            return $user;
        }

        $missedCount = $this->missedCompletedInitiativesCount($user);
        $attendedCount = $this->attendedCompletedInitiativesCount($user);

        if ($missedCount > self::MISSED_ATTENDANCE_LIMIT && $attendedCount === 0) {
            $user->forceFill([
                'initiative_registration_blocked_at' => now(),
                'initiative_registration_block_reason' => 'تجاوز 3 مبادرات مسجلة دون تأكيد أي حضور.',
            ])->save();
        }

        return $user->fresh();
    }

    public function refreshAllCitizens(): void
    {
        $citizenRoleId = Role::where('role_name', 'citizen')->value('id');
        if (! $citizenRoleId) {
            return;
        }

        User::where('role_id', $citizenRoleId)
            ->whereNull('initiative_registration_blocked_at')
            ->select('id')
            ->chunkById(100, function ($citizens) {
                foreach ($citizens as $citizen) {
                    $this->refreshUser(User::findOrFail($citizen->id));
                }
            });
    }

    public function missedCompletedInitiativesCount(User $user): int
    {
        return $user->initiativeRegistrations()
            ->where('status', 'registered')
            ->whereNull('attended_at')
            ->when($user->initiative_registration_unblocked_at, fn ($query) => $query
                ->where('registered_at', '>', $user->initiative_registration_unblocked_at))
            ->whereHas('initiative', fn ($query) => $query->where('status', 'completed'))
            ->count();
    }

    public function attendedCompletedInitiativesCount(User $user): int
    {
        return $user->initiativeRegistrations()
            ->whereNotNull('attended_at')
            ->when($user->initiative_registration_unblocked_at, fn ($query) => $query
                ->where('registered_at', '>', $user->initiative_registration_unblocked_at))
            ->whereHas('initiative', fn ($query) => $query->where('status', 'completed'))
            ->count();
    }
}
