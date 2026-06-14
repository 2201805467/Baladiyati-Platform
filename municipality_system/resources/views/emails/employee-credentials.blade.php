<x-mail::message>
# Baladiyati Employee Account

Hello {{ $user->full_name }},

Your Baladiyati employee account has been created.

**Email:** {{ $user->email }}

**Employee number:** {{ $user->employee_number }}

**Temporary password:** {{ $plainPassword }}

Please sign in and change your password as soon as possible.

Thanks,<br>
{{ config('app.name') }}
</x-mail::message>
