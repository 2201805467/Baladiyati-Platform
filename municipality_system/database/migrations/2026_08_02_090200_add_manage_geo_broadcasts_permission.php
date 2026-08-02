<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        DB::table('permissions')->updateOrInsert(
            ['permission_name' => 'manage_geo_broadcasts'],
            ['description' => 'Manage geographic emergency broadcasts']
        );

        $permissionId = DB::table('permissions')->where('permission_name', 'manage_geo_broadcasts')->value('id');
        $roleIds = DB::table('roles')->whereIn('role_name', ['admin', 'reception'])->pluck('id');

        foreach ($roleIds as $roleId) {
            DB::table('role_permissions')->updateOrInsert([
                'role_id' => $roleId,
                'permission_id' => $permissionId,
            ]);
        }
    }

    public function down(): void
    {
        $permissionId = DB::table('permissions')->where('permission_name', 'manage_geo_broadcasts')->value('id');
        if ($permissionId) {
            DB::table('role_permissions')->where('permission_id', $permissionId)->delete();
            DB::table('permissions')->where('id', $permissionId)->delete();
        }
    }
};
