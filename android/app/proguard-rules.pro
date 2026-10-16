# Room 2.2.5 arrives through ML Kit's WorkManager dependency and instantiates
# generated database implementations by reflection. AGP 9's strict R8 rules
# no longer preserve a default constructor from a class-only keep rule.
# Preserve that constructor explicitly while retaining release optimization.
-keep class * extends androidx.room.RoomDatabase {
    public <init>();
}

# These dependencies also ship class-only rules for reflective construction.
-keep class * extends androidx.work.InputMerger {
    public <init>();
}
-keep class * implements com.google.firebase.components.ComponentRegistrar {
    public <init>();
}
