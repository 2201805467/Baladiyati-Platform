<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class SuggestionVote extends Model
{
    protected $fillable = ['suggestion_id', 'citizen_id', 'vote_type'];
    
    public $timestamps = false; // نعتمد على created_at التلقائي في الـ Migration

    // الصوت ينتمي لاقتراح محدد
    public function suggestion(): BelongsTo
    {
        return $this->belongsTo(Suggestion::class, 'suggestion_id');
    }

    // الصوت يعود لمواطن محدد
    public function citizen(): BelongsTo
    {
        return $this->belongsTo(User::class, 'citizen_id');
    }
}