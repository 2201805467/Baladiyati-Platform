<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->decimal('home_latitude', 10, 7)->nullable()->after('dept_id');
            $table->decimal('home_longitude', 10, 7)->nullable()->after('home_latitude');
            $table->decimal('last_latitude', 10, 7)->nullable()->after('home_longitude');
            $table->decimal('last_longitude', 10, 7)->nullable()->after('last_latitude');
            $table->timestamp('last_location_at')->nullable()->after('last_longitude');
            $table->boolean('location_sharing_enabled')->default(true)->after('last_location_at');
        });
    }

    public function down(): void
    {
        Schema::table('users', function (Blueprint $table) {
            $table->dropColumn([
                'home_latitude',
                'home_longitude',
                'last_latitude',
                'last_longitude',
                'last_location_at',
                'location_sharing_enabled',
            ]);
        });
    }
};
