<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void
    {
        Schema::create('report_votes', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('report_id');
            $table->unsignedBigInteger('citizen_id');
            $table->string('vote_type', 10);
            $table->timestamps();

            $table->unique(['report_id', 'citizen_id']);
            $table->foreign('report_id')->references('id')->on('reports')->onDelete('cascade');
            $table->foreign('citizen_id')->references('id')->on('users')->onDelete('cascade');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('report_votes');
    }
};
