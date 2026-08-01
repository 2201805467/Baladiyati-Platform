<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->timestamp('initiative_registration_blocked_at')->nullable()->after('is_active');
            $table->timestamp('initiative_registration_unblocked_at')->nullable()->after('initiative_registration_blocked_at');
            $table->string('initiative_registration_block_reason')->nullable()->after('initiative_registration_unblocked_at');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'initiative_registration_blocked_at',
                'initiative_registration_unblocked_at',
                'initiative_registration_block_reason',
            ]);
        });
    }
};
