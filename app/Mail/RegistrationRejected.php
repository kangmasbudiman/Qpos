<?php

namespace App\Mail;

use App\Models\Merchant;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class RegistrationRejected extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public readonly Merchant $merchant,
        public readonly string   $rejectionReason,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Informasi Status Pendaftaran Merchant Anda',
        );
    }

    public function content(): Content
    {
        return new Content(
            view: 'emails.registration_rejected',
        );
    }
}
