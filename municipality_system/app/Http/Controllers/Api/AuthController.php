<?php

namespace App\Http\Controllers\Api;

use App\Mail\OtpCodeMail;
use App\Http\Controllers\Controller;
use App\Models\PendingRegistration;
use App\Models\Role;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Mail;
use Illuminate\Support\Facades\Storage;
use Illuminate\Validation\Rule;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    public function register(Request $request): JsonResponse
    {
        $data = $request->validate([
            'full_name' => ['required', 'string', 'max:100'],
            'email' => ['required', 'email', 'max:100'],
            'phone' => ['required', 'string', 'max:20'],
            'password' => ['required', 'string', 'min:6', 'confirmed'],
        ]);

        PendingRegistration::where('otp_expires_at', '<', now())->delete();

        User::where(function ($query) use ($data) {
            $query->where('email', $data['email'])
                ->orWhere('phone', $data['phone']);
        })
            ->where('is_active', false)
            ->where('otp_purpose', 'registration')
            ->delete();

        if (User::where('email', $data['email'])->exists()) {
            throw ValidationException::withMessages([
                'email' => ['The email has already been taken.'],
            ]);
        }

        if (User::where('phone', $data['phone'])->exists()) {
            throw ValidationException::withMessages([
                'phone' => ['The phone has already been taken.'],
            ]);
        }

        $existingPendingByPhone = PendingRegistration::where('phone', $data['phone'])
            ->where('email', '!=', $data['email'])
            ->first();

        if ($existingPendingByPhone) {
            throw ValidationException::withMessages([
                'phone' => ['The phone has already been used for a pending registration.'],
            ]);
        }

        $existingPendingRegistration = PendingRegistration::where('email', $data['email'])->first();
        $hasReusableOtp = $existingPendingRegistration?->otp_expires_at?->isFuture() === true;
        $otp = $hasReusableOtp ? $existingPendingRegistration->otp_code : $this->generateOtp();
        $otpExpiresAt = $hasReusableOtp
            ? $existingPendingRegistration->otp_expires_at
            : now()->addMinutes(10);

        $pendingRegistration = PendingRegistration::updateOrCreate([
            'email' => $data['email'],
        ], [
            'full_name' => $data['full_name'],
            'phone' => $data['phone'],
            'password' => Hash::make($data['password']),
            'otp_code' => $otp,
            'otp_expires_at' => $otpExpiresAt,
        ]);

        $this->sendOtpEmail($pendingRegistration->email, $pendingRegistration->full_name, $otp, 'registration');

        return response()->json([
            'message' => 'Registration successful. Verify the OTP sent to your email to activate your account.',
            'user' => [
                'id' => 0,
                'full_name' => $pendingRegistration->full_name,
                'email' => $pendingRegistration->email,
                'phone' => $pendingRegistration->phone,
            ],
            'otp_expires_at' => $pendingRegistration->otp_expires_at,
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
            'email' => ['required', 'email', 'max:100'],
            'otp_code' => ['required', 'string', 'max:10'],
            'purpose' => ['nullable', Rule::in(['registration', 'password_reset'])],
        ]);

        $purpose = $data['purpose'] ?? 'registration';

        $otpCode = $this->normalizeOtp($data['otp_code']);

        if ($purpose === 'registration') {
            $pendingRegistration = $this->findPendingRegistrationByEmail($data['email']);
            $this->ensureValidOtp($pendingRegistration, $otpCode, null);

            $user = DB::transaction(function () use ($pendingRegistration) {
                $citizenRole = Role::where('role_name', 'citizen')->firstOrFail();

                if (User::where('email', $pendingRegistration->email)->exists()) {
                    throw ValidationException::withMessages([
                        'email' => ['The email has already been taken.'],
                    ]);
                }

                if (User::where('phone', $pendingRegistration->phone)->exists()) {
                    throw ValidationException::withMessages([
                        'phone' => ['The phone has already been taken.'],
                    ]);
                }

                $user = User::create([
                    'full_name' => $pendingRegistration->full_name,
                    'email' => $pendingRegistration->email,
                    'phone' => $pendingRegistration->phone,
                    'password' => $pendingRegistration->password,
                    'is_active' => true,
                    'email_verified_at' => now(),
                    'role_id' => $citizenRole->id,
                    'dept_id' => null,
                ]);

                $pendingRegistration->delete();

                return $user;
            });

            return response()->json([
                'message' => 'Account verified successfully.',
                'user' => $user->fresh()->load('role', 'department'),
            ]);
        }

        $user = $this->findUserByEmail($data['email']);
        $this->ensureValidOtp($user, $otpCode, 'password_reset');

        return response()->json([
            'message' => 'OTP verified successfully.',
        ]);
    }

    public function resendOtp(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email', 'max:100'],
            'purpose' => ['required', Rule::in(['registration', 'password_reset'])],
        ]);

        if ($data['purpose'] === 'registration') {
            $pendingRegistration = $this->findPendingRegistrationByEmail($data['email']);
            $otp = $this->setOtp($pendingRegistration, $data['purpose']);
            $this->sendOtpEmail($pendingRegistration->email, $pendingRegistration->full_name, $otp, $data['purpose']);

            return response()->json([
                'message' => 'OTP sent to email successfully.',
                'otp_expires_at' => $pendingRegistration->fresh()->otp_expires_at,
                'dev_otp' => app()->isProduction() ? null : $otp,
            ]);
        }

        $user = $this->findUserByEmail($data['email']);
        $otp = $this->setOtp($user, $data['purpose']);
        $this->sendOtpEmail($user->email, $user->full_name, $otp, $data['purpose']);

        return response()->json([
            'message' => 'OTP sent to email successfully.',
            'otp_expires_at' => $user->fresh()->otp_expires_at,
            'dev_otp' => app()->isProduction() ? null : $otp,
        ]);
    }

    public function forgotPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email', 'max:100'],
        ]);

        $user = $this->findUserByEmail($data['email']);
        $otp = $this->setOtp($user, 'password_reset');
        $this->sendOtpEmail($user->email, $user->full_name, $otp, 'password_reset');

        return response()->json([
            'message' => 'Password reset OTP sent to email successfully.',
            'otp_expires_at' => $user->fresh()->otp_expires_at,
            'dev_otp' => app()->isProduction() ? null : $otp,
        ]);
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $data = $request->validate([
            'email' => ['required', 'email', 'max:100'],
            'otp_code' => ['required', 'string', 'max:10'],
            'password' => ['required', 'string', 'min:6', 'confirmed'],
        ]);

        $user = $this->findUserByEmail($data['email']);
        $this->ensureValidOtp($user, $this->normalizeOtp($data['otp_code']), 'password_reset');

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

    private function findUserByEmail(string $email): User
    {
        $user = User::where('email', $email)->first();

        if (! $user) {
            throw ValidationException::withMessages([
                'email' => ['No account was found for the provided email.'],
            ]);
        }

        return $user;
    }

    private function findPendingRegistrationByEmail(string $email): PendingRegistration
    {
        $pendingRegistration = PendingRegistration::where('email', $email)->first();

        if (! $pendingRegistration) {
            throw ValidationException::withMessages([
                'email' => ['No pending registration was found for the provided email. Please register again.'],
            ]);
        }

        return $pendingRegistration;
    }

    private function setOtp(User|PendingRegistration $record, string $purpose): string
    {
        $otp = $this->generateOtp();

        $attributes = [
            'otp_code' => $otp,
            'otp_expires_at' => now()->addMinutes(10),
        ];

        if ($record instanceof User) {
            $attributes['otp_purpose'] = $purpose;
        }

        $record->update($attributes);

        return $otp;
    }

    private function ensureValidOtp(User|PendingRegistration $record, string $otp, ?string $purpose): void
    {
        if (
            ! $record->otp_code ||
            ! hash_equals($record->otp_code, $otp) ||
            ($purpose && $record instanceof User && $record->otp_purpose !== $purpose) ||
            ! $record->otp_expires_at ||
            $record->otp_expires_at->isPast()
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

    private function normalizeOtp(string $otp): string
    {
        return strtr(trim($otp), [
            '٠' => '0',
            '١' => '1',
            '٢' => '2',
            '٣' => '3',
            '٤' => '4',
            '٥' => '5',
            '٦' => '6',
            '٧' => '7',
            '٨' => '8',
            '٩' => '9',
            '۰' => '0',
            '۱' => '1',
            '۲' => '2',
            '۳' => '3',
            '۴' => '4',
            '۵' => '5',
            '۶' => '6',
            '۷' => '7',
            '۸' => '8',
            '۹' => '9',
        ]);
    }

    private function sendOtpEmail(string $email, string $fullName, string $otp, string $purpose): void
    {
        Mail::to($email)->send(new OtpCodeMail($fullName, $otp, $purpose));
    }
}
