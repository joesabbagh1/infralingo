package com.infralingo.domain

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

data class Day(
    val date: LocalDate,
    val xp: Int,
    val answers: Int,
)

/** Streak and daily totals come straight from the answer log, so they cannot drift from it. */
object Activity {
    fun days(reviews: List<ReviewState>, zone: ZoneId): Map<LocalDate, Day> =
        reviews
            .groupBy { Instant.ofEpochMilli(it.at).atZone(zone).toLocalDate() }
            .mapValues { (date, onDay) -> Day(date, onDay.sumOf { it.xp }, onDay.size) }

    fun streak(practiced: Set<LocalDate>, today: LocalDate): Int {
        // A day that has not been practiced yet does not break the streak until it ends.
        var cursor = if (today in practiced) today else today.minusDays(1)
        var count = 0
        while (cursor in practiced) {
            count += 1
            cursor = cursor.minusDays(1)
        }
        return count
    }
}
