<?php
use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration {
    public function up(): void {
        Schema::create('suggestion_votes', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('suggestion_id');
            $table->unsignedBigInteger('citizen_id');
            $table->string('vote_type', 50);
            $table->timestamp('created_at')->useCurrent();
            $table->unique(['suggestion_id', 'citizen_id']);
            $table->foreign('suggestion_id')->references('id')->on('suggestions')->onDelete('cascade');
            $table->foreign('citizen_id')->references('id')->on('users')->onDelete('cascade');
        });
    }
    public function down(): void {
        Schema::dropIfExists('suggestion_votes');
    }
};