<?php

namespace App\Mail;

use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class OtpCodeMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public string $fullName,
        public string $otpCode,
        public string $purpose
    ) {
    }

    public function envelope(): Envelope
    {
        return new Envelope(
            subject: $this->purpose === 'password_reset'
                ? 'Baladiyati password reset code'
                : 'Baladiyati email verification code',
        );
    }

    public function content(): Content
    {
        return new Content(
            markdown: 'emails.otp-code',
        );
    }
}
