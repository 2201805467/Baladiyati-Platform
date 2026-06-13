<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Suggestion extends Model
{
    protected $fillable = ['citizen_id', 'title', 'description', 'category', 'status', 'rejection_reason', 'reviewed_by'];

    // مقدم الاقتراح
    public function citizen(): BelongsTo
    {
        return $this->belongsTo(User::class, 'citizen_id');
    }

    // الموظف أو المسؤول الذي راجع الاقتراح
    public function reviewer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by');
    }

    // الاقتراح يمتلك العديد من أصوات التأييد/الرفض من المواطنين
    public function votes(): HasMany
    {
        return $this->hasMany(SuggestionVote::class, 'suggestion_id');
    }
}