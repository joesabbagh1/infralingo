package com.infralingo.data

import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Index
import androidx.room.Insert
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.RoomDatabase
import androidx.room.Transaction
import androidx.room.Upsert
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import com.infralingo.domain.Outcome

@Entity(tableName = "attempts")
data class AttemptEntity(
    @PrimaryKey val questionId: String,
    val skillId: String,
    val intervalDays: Int,
    val dueAt: Long,
    val correctStreak: Int,
    val lapses: Int,
    val timesCorrect: Int,
    val timesWrong: Int,
)

@Entity(
    tableName = "reviews",
    indices = [Index("skillId"), Index("at")],
)
data class ReviewEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val questionId: String,
    val skillId: String,
    val correct: Boolean,
    val hinted: Boolean,
    val xp: Int,
    val at: Long,
)

@Entity(tableName = "profile")
data class ProfileEntity(
    @PrimaryKey val id: Int = 1,
    val dailyGoal: Int,
    val lastSkillId: String?,
)

@Dao
interface ProgressDao {
    @Query("SELECT * FROM attempts")
    suspend fun attempts(): List<AttemptEntity>

    @Query("SELECT * FROM attempts WHERE questionId = :questionId")
    suspend fun attempt(questionId: String): AttemptEntity?

    @Query("SELECT * FROM reviews ORDER BY at ASC, id ASC")
    suspend fun reviews(): List<ReviewEntity>

    @Query("SELECT * FROM profile WHERE id = 1")
    suspend fun profile(): ProfileEntity?

    @Upsert
    suspend fun upsertAttempt(entity: AttemptEntity)

    @Insert
    suspend fun insertReview(entity: ReviewEntity)

    @Upsert
    suspend fun upsertProfile(entity: ProfileEntity)

    @Insert
    suspend fun insertAttempts(entities: List<AttemptEntity>)

    @Insert
    suspend fun insertReviews(entities: List<ReviewEntity>)

    @Query("DELETE FROM attempts")
    suspend fun clearAttempts()

    @Query("DELETE FROM reviews")
    suspend fun clearReviews()

    @Transaction
    suspend fun recordAnswer(attempt: AttemptEntity, review: ReviewEntity) {
        upsertAttempt(attempt)
        insertReview(review)
    }

    @Transaction
    suspend fun replaceAll(profile: ProfileEntity, attempts: List<AttemptEntity>, reviews: List<ReviewEntity>) {
        clearAttempts()
        clearReviews()
        upsertProfile(profile)
        if (attempts.isNotEmpty()) insertAttempts(attempts)
        if (reviews.isNotEmpty()) insertReviews(reviews)
    }
}

@Database(
    entities = [AttemptEntity::class, ReviewEntity::class, ProfileEntity::class],
    version = 2,
    exportSchema = false,
)
abstract class ProgressDatabase : RoomDatabase() {
    abstract fun progressDao(): ProgressDao

    companion object {
        /**
         * Version 1 kept the streak and placement result in the profile row. Both are gone: the streak is now
         * read from the answer log, and reviews carry the hint flag and XP that log needs.
         */
        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("ALTER TABLE reviews ADD COLUMN hinted INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE reviews ADD COLUMN xp INTEGER NOT NULL DEFAULT 0")
                db.execSQL("UPDATE reviews SET xp = ${Outcome.CLEAN.xp} WHERE correct = 1")
                db.execSQL("DROP TABLE profile")
                db.execSQL(
                    "CREATE TABLE profile (" +
                        "id INTEGER NOT NULL, dailyGoal INTEGER NOT NULL, lastSkillId TEXT, PRIMARY KEY(id))",
                )
            }
        }
    }
}
