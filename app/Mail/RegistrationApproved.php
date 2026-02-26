<?php

namespace App\Mail;

use App\Models\Merchant;
use Illuminate\Bus\Queueable;
use Illuminate\Mail\Mailable;
use Illuminate\Mail\Mailables\Content;
use Illuminate\Mail\Mailables\Envelope;
use Illuminate\Queue\SerializesModels;

class RegistrationApproved extends Mailable
{
    use Queueable, SerializesModels;

    public function __construct(
        public readonly Merchant $merchant,
        public readonly string   $companyCode,
    ) {}

    public function envelope(): Envelope
    {
        return new Envelope(
            subject: 'Selamat! Pendaftaran Merchant Anda Telah Disetujui',
        );
    }

    public function content(): Content
    {
        return new Content(
            view: 'emails.registration_approved',
        );
    }
}
