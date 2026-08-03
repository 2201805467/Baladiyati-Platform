<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            $table->timestamp('field_started_at')->nullable()->after('sla_due_at');
            $table->timestamp('field_finished_at')->nullable()->after('field_started_at');
            $table->decimal('field_start_latitude', 10, 8)->nullable()->after('field_finished_at');
            $table->decimal('field_start_longitude', 11, 8)->nullable()->after('field_start_latitude');
            $table->decimal('field_finish_latitude', 10, 8)->nullable()->after('field_start_longitude');
            $table->decimal('field_finish_longitude', 11, 8)->nullable()->after('field_finish_latitude');
            $table->unsignedInteger('field_execution_duration_seconds')->nullable()->after('field_finish_longitude');
        });
    }

    public function down(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            $table->dropColumn([
                'field_started_at',
                'field_finished_at',
                'field_start_latitude',
                'field_start_longitude',
                'field_finish_latitude',
                'field_finish_longitude',
                'field_execution_duration_seconds',
            ]);
        });
    }
};
