<?php

namespace App\Services;

use App\Models\Role;
use App\Models\User;
use Illuminate\Support\Collection;

class GeoBroadcastTargetingService
{
    public function targetedCitizens(float $latitude, float $longitude, int $radiusMeters): Collection
    {
        $citizenRoleId = Role::where('role_name', 'citizen')->value('id');
        if (! $citizenRoleId) {
            return collect();
        }

        return User::where('role_id', $citizenRoleId)
            ->where('is_active', true)
            ->get()
            ->map(function (User $user) use ($latitude, $longitude, $radiusMeters) {
                $homeMatch = $this->hasPointInsideRadius($user->home_latitude, $user->home_longitude, $latitude, $longitude, $radiusMeters);
                $liveMatch = $user->location_sharing_enabled
                    && $this->hasPointInsideRadius($user->last_latitude, $user->last_longitude, $latitude, $longitude, $radiusMeters);

                if (! $homeMatch && ! $liveMatch) {
                    return null;
                }

                $user->matched_by = $homeMatch && $liveMatch ? 'home_and_live' : ($homeMatch ? 'home' : 'live');

                return $user;
            })
            ->filter()
            ->values();
    }

    public function hasPointInsideRadius(mixed $pointLat, mixed $pointLng, float $centerLat, float $centerLng, int $radiusMeters): bool
    {
        if ($pointLat === null || $pointLng === null) {
            return false;
        }

        return $this->distanceMeters(
            (float) $pointLat,
            (float) $pointLng,
            $centerLat,
            $centerLng
        ) <= $radiusMeters;
    }

    private function distanceMeters(float $lat1, float $lng1, float $lat2, float $lng2): float
    {
        $earthRadius = 6371000;
        $latDelta = deg2rad($lat2 - $lat1);
        $lngDelta = deg2rad($lng2 - $lng1);
        $a = sin($latDelta / 2) ** 2
            + cos(deg2rad($lat1)) * cos(deg2rad($lat2)) * sin($lngDelta / 2) ** 2;

        return $earthRadius * 2 * atan2(sqrt($a), sqrt(1 - $a));
    }
}
