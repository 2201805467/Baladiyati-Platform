<?php

namespace App\Mail;

use App\Models\User;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class EmployeeCredentialsMail extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public User $user,
        public string $plainPassword
    ) {
    }

    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Baladiyati employee account credentials',
        );
    }

    public function content(): Content
    {
        return new Content(
            markdown: 'emails.employee-credentials',
        );
    }
}
