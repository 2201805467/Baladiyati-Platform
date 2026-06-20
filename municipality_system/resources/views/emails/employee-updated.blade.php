<x-mail::message>
# Baladiyati Employee Account Updated

Hello {{ $user->full_name }},

Your Baladiyati employee account information has been updated.

**Email:** {{ $user->email }}

**Phone:** {{ $user->phone }}

**Employee number:** {{ $user->employee_number }}

**Role:** {{ $user->role?->role_name }}

@if($user->department)
**Department:** {{ $user->department->dept_name }}
@endif

@if($plainPassword)
**New password:** {{ $plainPassword }}

Please sign in and change your password as soon as possible.
@endif

Thanks,<br>
{{ config('app.name') }}
</x-mail::message>
