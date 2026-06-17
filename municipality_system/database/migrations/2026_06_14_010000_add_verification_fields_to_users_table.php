<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('phone_verified_at')->nullable()->after('profile_image');
            $table->timestamp('email_verified_at')->nullable()->after('phone_verified_at');
            $table->string('otp_code', 10)->nullable()->after('email_verified_at');
            $table->string('otp_purpose', 30)->nullable()->after('otp_code');
            $table->timestamp('otp_expires_at')->nullable()->after('otp_purpose');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'phone_verified_at',
                'email_verified_at',
                'otp_code',
                'otp_purpose',
                'otp_expires_at',
            ]);
        });
    }
};
