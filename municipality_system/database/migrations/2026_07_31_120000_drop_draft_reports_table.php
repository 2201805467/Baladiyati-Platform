<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::dropIfExists('draft_reports');
    }

    public function down(): void
    {
        // The draft report feature was removed from the system.
    }
};
