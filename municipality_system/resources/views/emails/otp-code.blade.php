<x-mail::message>
# Baladiyati Verification Code

Hello {{ $fullName }},

Your verification code is:

<x-mail::panel>
{{ $otpCode }}
</x-mail::panel>

This code expires in 10 minutes.

Thanks,<br>
{{ config('app.name') }}
</x-mail::message>
