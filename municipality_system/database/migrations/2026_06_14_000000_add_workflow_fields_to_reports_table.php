<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            $table->text('rejection_reason')->nullable()->after('parent_report_id');
            $table->text('completion_report')->nullable()->after('rejection_reason');
            $table->timestamp('sla_due_at')->nullable()->after('closed_at');
        });
    }

    public function down(): void
    {
        Schema::table('reports', function (Blueprint $table) {
            $table->dropColumn(['rejection_reason', 'completion_report', 'sla_due_at']);
        });
    }
};
