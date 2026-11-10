package com.infralingo

import android.app.Application
import androidx.room.Room
import com.infralingo.data.ContentRepository
import com.infralingo.data.ProgressDatabase
import com.infralingo.data.ProgressRepository

class InfralingoApplication : Application() {
    lateinit var contentRepository: ContentRepository
        private set
    lateinit var progressRepository: ProgressRepository
        private set

    override fun onCreate() {
        super.onCreate()
        contentRepository = ContentRepository(assets)
        val database = Room.databaseBuilder(this, ProgressDatabase::class.java, "infralingo.db")
            .addMigrations(ProgressDatabase.MIGRATION_1_2)
            .build()
        progressRepository = ProgressRepository(database.progressDao())
    }
}
