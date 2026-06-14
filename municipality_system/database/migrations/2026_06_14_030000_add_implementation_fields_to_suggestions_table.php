<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('suggestions', function (Blueprint $table) {
            $table->string('implementation_status', 50)->nullable()->after('reviewed_by');
            $table->unsignedTinyInteger('implementation_progress_percent')->default(0)->after('implementation_status');
            $table->text('implementation_note')->nullable()->after('implementation_progress_percent');
        });
    }

    public function down(): void
    {
        Schema::table('suggestions', function (Blueprint $table) {
            $table->dropColumn([
                'implementation_status',
                'implementation_progress_percent',
                'implementation_note',
            ]);
        });
    }
};
