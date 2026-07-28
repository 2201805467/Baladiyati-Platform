<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasColumn('reports', 'voice_note_url')) {
            Schema::table('reports', function (Blueprint $table) {
                $table->dropColumn('voice_note_url');
            });
        }
    }

    public function down(): void
    {
        if (! Schema::hasColumn('reports', 'voice_note_url')) {
            Schema::table('reports', function (Blueprint $table) {
                $table->string('voice_note_url')->nullable()->after('description');
            });
        }
    }
};
