<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'full_name' => ['required', 'string', 'max:100'],
            'email' => ['required', 'email', 'max:100', 'unique:users,email'],
            'phone' => ['required', 'string', 'max:20', 'unique:users,phone'],
            'password' => ['required', 'string', 'min:6', 'confirmed'],
        ]);

        $citizenRole = Role::where('role_name', 'citizen')->firstOrFail();
        $otp = $this->generateOtp();

        $user = User::create([
            'full_name' => $data['full_name'],
            'email' => $data['email'],
            'phone' => $data['phone'],
            'password' => Hash::make($data['password']),
            'is_active' => false,
            'role_id' => $citizenRole->id,
            'dept_id' => null,
            'otp_code' => $otp,
            'otp_purpose' => 'registration',
            'otp_expires_at' => now()->addMinutes(10),
        ]);

        return response()->json([
            'message' => 'Registration successful. Verify the OTP to activate your account.',
            'user' => $user->load('role', 'department'),
            'otp_expires_at' => $user->otp_expires_at,
            'dev_otp' => app()->isProduction() ? null : $otp,
        ], 201);
    }

    public function login(Request $request): JsonResponse
    {
        $credentials = $request->validate([
            'login' => ['required', 'string'],
            'password' => ['required', 'string'],
            'device_name' => ['nullable', 'string', 'max:100'],
        ]);

        $user = User::with('role', 'department')
            ->where('email', $credentials['login'])
            ->orWhere('phone', $credentials['login'])
            ->first();

        if (! $user || ! Hash::check($credentials['password'], $user->password)) {
            throw ValidationException::withMessages([
                'login' => ['The provided credentials are incorrect.'],
            ]);
        }

        if (! $user->is_active) {
            return response()->json([
                'message' => $user->otp_purpose === 'registration'
                    ? 'This account is not verified yet.'
                    : 'This account is deactivated.',
            ], 403);
        }

        $roleName = $user->role?->role_name;
        $deviceName = $credentials['device_name'] ?? 'api-client';
        $token = $user->createToken($deviceName, [$roleName])->plainTextToken;

        return response()->json([
            'token_type' => 'Bearer',
            'access_token' => $token,
            'user' => $user,
        ]);
    }

    public function verifyOtp(Request $request): JsonResponse
    {
        $data = $request->validate([
            'phone' => ['required_without:email', 'string', 'max:20'],
            'email' => ['required_without:phone', 'email', 'max:100'],
            'otp_code' => ['required', 'string', 'max:10'],
            'purpose' => ['nullable', Rule::in(['registration', 'password_reset'])],
        ]);

        $user = $this->findUserByLogin($data['email'] ?? $data['phone']);
        $this->ensureValidOtp($user, $data['otp_code'], $data['purpose'] ?? null);

        if ($user->otp_purpose === 'registration') {
            $user->update([
                'is_active' => true,
                'phone_verified_at' => now(),
                'otp_code' => null,
                'otp_purpose' => null,
                'otp_expires_at' => null,
            ]);

            return response()->json([
                'message' => 'Account verified successfully.',
                'user' => $user->fresh()->load('role', 'department'),
            ]);
        }

        return response()->json([
            'message' => 'OTP verified successfully.',
        ]);
    }

    public function resendOtp(Request $request): JsonResponse
    {
        $data = $request->validate([
            'phone' => ['required_without:email', 'string', 'max:20'],
            'email' => ['required_without:phone', 'email', 'max:100'],
            'purpose' => ['required', Rule::in(['registration', 'password_reset'])],
        ]);

        $user = $this->findUserByLogin($data['email'] ?? $data['phone']);
        $otp = $this->setOtp($user, $data['purpose']);

        return response()->json([
            'message' => 'OTP sent successfully.',
            'otp_expires_at' => $user->fresh()->otp_expires_at,
            'dev_otp' => app()->isProduction() ? null : $otp,
        ]);
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'login' => ['required', 'string'],
        ]);

        $user = $this->findUserByLogin($data['login']);
        $otp = $this->setOtp($user, 'password_reset');

        return response()->json([
            'message' => 'Password reset OTP sent successfully.',
            'otp_expires_at' => $user->fresh()->otp_expires_at,
            'dev_otp' => app()->isProduction() ? null : $otp,
        ]);
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'login' => ['required', 'string'],
            'otp_code' => ['required', 'string', 'max:10'],
            'password' => ['required', 'string', 'min:6', 'confirmed'],
        ]);

        $user = $this->findUserByLogin($data['login']);
        $this->ensureValidOtp($user, $data['otp_code'], 'password_reset');

        $user->update([
            'password' => Hash::make($data['password']),
            'is_active' => true,
            'otp_code' => null,
            'otp_purpose' => null,
            'otp_expires_at' => null,
        ]);

        $user->tokens()->delete();

        return response()->json([
            'message' => 'Password reset successfully.',
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        return response()->json([
            'user' => $request->user()->load('role', 'department'),
        ]);
    }

    public function logout(Request $request): JsonResponse
    {
        $request->user()->currentAccessToken()?->delete();

        return response()->json([
            'message' => 'Logged out successfully.',
        ]);
    }

    public function updateProfile(Request $request): JsonResponse
    {
        $data = $request->validate([
            'full_name' => ['sometimes', 'required', 'string', 'max:100'],
            'profile_image' => ['sometimes', 'image', 'mimes:jpg,jpeg,png', 'max:5120'],
        ]);

        $user = $request->user();

        if ($request->hasFile('profile_image')) {
            $path = $request->file('profile_image')->store('profiles/'.$user->id, 'public');
            $data['profile_image'] = Storage::url($path);
        }

        $user->update($data);

        return response()->json([
            'message' => 'Profile updated successfully.',
            'user' => $user->fresh()->load('role', 'department'),
        ]);
    }

    public function changePassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'current_password' => ['required', 'string'],
            'password' => ['required', 'string', 'min:6', 'confirmed'],
        ]);

        $user = $request->user();

        if (! Hash::check($data['current_password'], $user->password)) {
            throw ValidationException::withMessages([
                'current_password' => ['The current password is incorrect.'],
            ]);
        }

        $user->update([
            'password' => Hash::make($data['password']),
        ]);

        return response()->json([
            'message' => 'Password changed successfully.',
        ]);
    }

    private function findUserByLogin(string $login): User
    {
        $user = User::where('email', $login)
            ->orWhere('phone', $login)
            ->first();

        if (! $user) {
            throw ValidationException::withMessages([
                'login' => ['No account was found for the provided identifier.'],
            ]);
        }

        return $user;
    }

    private function setOtp(User $user, string $purpose): string
    {
        $otp = $this->generateOtp();

        $user->update([
            'otp_code' => $otp,
            'otp_purpose' => $purpose,
            'otp_expires_at' => now()->addMinutes(10),
        ]);

        return $otp;
    }

    private function ensureValidOtp(User $user, string $otp, ?string $purpose): void
    {
        if (
            ! $user->otp_code ||
            ! hash_equals($user->otp_code, $otp) ||
            ($purpose && $user->otp_purpose !== $purpose) ||
            ! $user->otp_expires_at ||
            $user->otp_expires_at->isPast()
        ) {
            throw ValidationException::withMessages([
                'otp_code' => ['The OTP code is invalid or expired.'],
            ]);
        }
    }

    private function generateOtp(): string
    {
        return (string) random_int(100000, 999999);
    }
}
