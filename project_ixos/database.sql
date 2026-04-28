-- =============================================================================
-- MOOD MUSIC APP — PostgreSQL Schema v3.0 (optimized)
-- =============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS unaccent;

-- ─────────────────────────────────────────────────────────────────────────────
-- ENUMS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TYPE repeat_mode  AS ENUM ('none', 'one', 'all');
CREATE TYPE dl_status    AS ENUM ('pending', 'downloading', 'completed', 'failed');
CREATE TYPE visibility   AS ENUM ('private', 'friends', 'public');

-- ─────────────────────────────────────────────────────────────────────────────
-- CATALOG
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE artists (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name             TEXT NOT NULL,
    bio              TEXT,
    image_url        TEXT,
    country          CHAR(2),
    verified         BOOLEAN NOT NULL DEFAULT FALSE,
    monthly_listeners INT    NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Full-text search
    search_vector    tsvector GENERATED ALWAYS AS (
        to_tsvector('spanish', coalesce(name,'') || ' ' || coalesce(bio,''))
    ) STORED
);

CREATE TABLE albums (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    title        TEXT NOT NULL,
    artist_id    UUID NOT NULL REFERENCES artists(id) ON DELETE CASCADE,
    release_date DATE,
    cover_url    TEXT,
    total_tracks SMALLINT,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    search_vector tsvector GENERATED ALWAYS AS (
        to_tsvector('spanish', coalesce(title,''))
    ) STORED
);

-- release_year dropped: use EXTRACT(YEAR FROM release_date) in queries — no need to store it twice

CREATE TABLE genres (
    id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name     TEXT NOT NULL UNIQUE,
    color_hex CHAR(7),
    icon_name TEXT
);

INSERT INTO genres (name, color_hex, icon_name) VALUES
    ('Pop',         '#F72585', 'star'),
    ('Rock',        '#7B2D8B', 'guitar'),
    ('Hip-Hop',     '#F4A261', 'microphone'),
    ('Electronic',  '#4CC9F0', 'wave'),
    ('Jazz',        '#E9C46A', 'music'),
    ('Clásica',     '#264653', 'music'),
    ('Reggaeton',   '#E76F51', 'fire'),
    ('R&B / Soul',  '#9B5DE5', 'heart'),
    ('Lo-Fi',       '#06D6A0', 'cloud'),
    ('Metal',       '#2B2D42', 'skull'),
    ('Ambient',     '#80B3FF', 'leaf'),
    ('Latin',       '#FF6B6B', 'music'),
    ('Alternative', '#A8DADC', 'guitar');

CREATE TABLE songs (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),

    -- File identity (from ingest pipeline JSON)
    file_id      TEXT NOT NULL UNIQUE,  -- "b8f5c4be-....mp3"
    file_path    TEXT NOT NULL,          -- "music/{uuid}.mp3"
    cdn_url      TEXT,                   -- populated after publish
    preview_url  TEXT,                   -- 30-sec clip

    -- Metadata
    title        TEXT NOT NULL,
    artist_id    UUID NOT NULL REFERENCES artists(id) ON DELETE RESTRICT,
    album_id     UUID REFERENCES albums(id) ON DELETE SET NULL,
    track_number SMALLINT,
    cover_url    TEXT,
    release_year SMALLINT,              -- from JSON "anio" — year only, no full date available
    explicit     BOOLEAN NOT NULL DEFAULT FALSE,
    play_count   BIGINT  NOT NULL DEFAULT 0,

    -- Audio specs (all straight from the pipeline JSON)
    duration_s   NUMERIC(10,2) NOT NULL,  -- "duracion": 222.12
    bitrate      INT NOT NULL,             -- "bitrate": 192000
    sample_rate  INT NOT NULL,             -- "sample_rate": 48000
    channels     SMALLINT NOT NULL DEFAULT 2,

    -- Audio analysis (populated later via AcousticBrainz / external API)
    bpm          NUMERIC(6,2),
    energy       NUMERIC(4,3),  -- 0–1
    valence      NUMERIC(4,3),  -- 0–1 (musical positiveness)

    -- Waveform for visualizer (~1000 amplitude samples, 0–255)
    waveform_data SMALLINT[],

    streamable   BOOLEAN NOT NULL DEFAULT TRUE,
    downloadable BOOLEAN NOT NULL DEFAULT TRUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    search_vector tsvector GENERATED ALWAYS AS (
        to_tsvector('spanish', coalesce(title,''))
    ) STORED
);

-- Dropped: acousticness, instrumentalness, loudness_db, musical_key, time_signature,
--          isrc — unused in any app feature described; easy to add back if needed

CREATE TABLE song_genres (
    song_id  UUID NOT NULL REFERENCES songs(id)  ON DELETE CASCADE,
    genre_id UUID NOT NULL REFERENCES genres(id) ON DELETE CASCADE,
    PRIMARY KEY (song_id, genre_id)
);

-- Time-synced lyrics (ms precision required for karaoke sync)
CREATE TABLE lyrics (
    song_id    UUID     NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    line_index SMALLINT NOT NULL,
    start_ms   INT      NOT NULL,
    end_ms     INT      NOT NULL,
    text       TEXT     NOT NULL,
    PRIMARY KEY (song_id, line_index)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- MOOD ENGINE
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE moods (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name           TEXT NOT NULL UNIQUE,
    display_name   TEXT NOT NULL,
    icon_name      TEXT NOT NULL,
    gradient_start CHAR(7) NOT NULL,
    gradient_end   CHAR(7) NOT NULL,
    sort_order     SMALLINT NOT NULL DEFAULT 0,
    -- Audio ranges used to auto-tag songs
    energy_min     NUMERIC(4,3), energy_max NUMERIC(4,3),
    valence_min    NUMERIC(4,3), valence_max NUMERIC(4,3),
    bpm_min        NUMERIC(6,2), bpm_max    NUMERIC(6,2)
);

INSERT INTO moods (name, display_name, icon_name, gradient_start, gradient_end, sort_order,
                   energy_min, energy_max, valence_min, valence_max, bpm_min, bpm_max) VALUES
    ('feliz',     'Feliz',     'smile',    '#FACC15','#F97316', 1, 0.6,1.0, 0.6,1.0, 100,180),
    ('triste',    'Triste',    'cloud',    '#475569','#1E3A5F', 2, 0.0,0.4, 0.0,0.4,  50,100),
    ('focus',     'Focus',     'headphones','#6366F1','#7C3AED',3, 0.3,0.7, 0.2,0.6,  80,130),
    ('energia',   'Energía',   'bolt',     '#DC2626','#18181B', 4, 0.7,1.0, 0.5,1.0, 120,200),
    ('relax',     'Relax',     'leaf',     '#2DD4BF','#059669', 5, 0.0,0.4, 0.3,0.7,  50, 95),
    ('fiesta',    'Fiesta',    'music',    '#EC4899','#E11D48', 6, 0.7,1.0, 0.6,1.0, 115,175),
    ('dormir',    'Dormir',    'moon',     '#1C1917','#000000', 7, 0.0,0.25,0.0,0.4,  40, 80),
    ('romance',   'Romance',   'heart',    '#FB7185','#EF4444', 8, 0.2,0.6, 0.4,0.8,  60,110),
    ('nostalgia', 'Nostalgia', 'clock',    '#92400E','#78350F', 9, 0.2,0.6, 0.3,0.7,  70,120);

-- Song ↔ mood mapping with AI confidence score
CREATE TABLE song_moods (
    song_id  UUID         NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    mood_id  UUID         NOT NULL REFERENCES moods(id) ON DELETE CASCADE,
    score    NUMERIC(4,3) NOT NULL DEFAULT 1.0, -- 1.0 = manual, <1 = AI-tagged
    PRIMARY KEY (song_id, mood_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- USERS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE users (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username     TEXT NOT NULL UNIQUE,
    email        TEXT NOT NULL UNIQUE,
    display_name TEXT,
    avatar_url   TEXT,
    country      CHAR(2),
    -- Active mood drives the app theme; NULL = no mood selected
    active_mood_id UUID REFERENCES moods(id) ON DELETE SET NULL,
    -- Preferences (flat columns — no need for a separate table at this scale)
    stream_quality  TEXT NOT NULL DEFAULT 'normal', -- low|normal|high|lossless
    show_explicit   BOOLEAN NOT NULL DEFAULT TRUE,
    autoplay        BOOLEAN NOT NULL DEFAULT TRUE,
    crossfade_ms    INT     NOT NULL DEFAULT 0,
    is_premium      BOOLEAN NOT NULL DEFAULT FALSE,
    premium_until   DATE,                           -- NULL = free or indefinite
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    last_login_at TIMESTAMPTZ
);

-- Dropped: user_preferences (merged into users), user_mood_sessions (one active mood is enough),
--          followed_artists (nice-to-have, add when needed), bio, date_of_birth,
--          preferred_language, updated_at (rarely queried)

-- ─────────────────────────────────────────────────────────────────────────────
-- LIBRARY
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE liked_songs (
    user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    song_id  UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    liked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, song_id)
);

CREATE TABLE downloads (
    user_id         UUID      NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    song_id         UUID      NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    status          dl_status NOT NULL DEFAULT 'pending',
    quality         TEXT      NOT NULL DEFAULT 'normal',
    file_size_bytes BIGINT,
    local_path      TEXT,
    downloaded_at   TIMESTAMPTZ,
    expires_at      TIMESTAMPTZ,
    PRIMARY KEY (user_id, song_id)
);

-- Dropped: surrogate PK on downloads — (user_id, song_id) is already unique

-- ─────────────────────────────────────────────────────────────────────────────
-- PLAYLISTS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE playlists (
    id             UUID       PRIMARY KEY DEFAULT uuid_generate_v4(),
    owner_id       UUID       NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name           TEXT       NOT NULL,
    description    TEXT,
    cover_url      TEXT,
    visibility     visibility NOT NULL DEFAULT 'private',
    is_mood_based  BOOLEAN    NOT NULL DEFAULT FALSE,
    mood_id        UUID       REFERENCES moods(id) ON DELETE SET NULL,
    gradient_start CHAR(7),
    gradient_end   CHAR(7),
    -- Denormalized counters maintained by trigger
    total_songs    INT          NOT NULL DEFAULT 0,
    total_duration_s NUMERIC(12,2) NOT NULL DEFAULT 0,
    created_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ  NOT NULL DEFAULT NOW(),

    search_vector tsvector GENERATED ALWAYS AS (
        to_tsvector('spanish', coalesce(name,'') || ' ' || coalesce(description,''))
    ) STORED
);

CREATE TABLE playlist_songs (
    playlist_id UUID NOT NULL REFERENCES playlists(id) ON DELETE CASCADE,
    song_id     UUID NOT NULL REFERENCES songs(id)     ON DELETE CASCADE,
    position    INT  NOT NULL,
    added_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (playlist_id, song_id),
    UNIQUE (playlist_id, position)
);

-- Dropped: surrogate PK, added_by — not core, can add later

-- ─────────────────────────────────────────────────────────────────────────────
-- PLAYER
-- ─────────────────────────────────────────────────────────────────────────────

-- Persisted so the app can restore state on relaunch
CREATE TABLE player_state (
    user_id         UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    current_song_id UUID REFERENCES songs(id) ON DELETE SET NULL,
    position_s      NUMERIC(10,2) NOT NULL DEFAULT 0,
    repeat          repeat_mode   NOT NULL DEFAULT 'none',
    shuffle         BOOLEAN       NOT NULL DEFAULT FALSE,
    volume          NUMERIC(4,3)  NOT NULL DEFAULT 1.0,
    updated_at      TIMESTAMPTZ   NOT NULL DEFAULT NOW()
);

-- Live queue stored client-side; only persist for cross-device restore
CREATE TABLE user_queue (
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    song_id     UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    position    INT  NOT NULL,
    source_type TEXT,   -- 'playlist'|'album'|'mood'|'search'|'dj'|'party'
    source_id   UUID,
    PRIMARY KEY (user_id, position)
);

-- Dropped: surrogate PK on user_queue — (user_id, position) is already unique

-- ─────────────────────────────────────────────────────────────────────────────
-- LISTENING HISTORY  (partitioned by month)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE listening_history (
    id          UUID        DEFAULT uuid_generate_v4(),
    user_id     UUID        NOT NULL REFERENCES users(id)  ON DELETE CASCADE,
    song_id     UUID        NOT NULL REFERENCES songs(id)  ON DELETE CASCADE,
    listened_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    duration_s  NUMERIC(10,2) NOT NULL CHECK (duration_s >= 0),
    completed   BOOLEAN     NOT NULL DEFAULT FALSE,
    mood_id     UUID        REFERENCES moods(id) ON DELETE SET NULL,
    source_type TEXT,
    PRIMARY KEY (id, listened_at)
) PARTITION BY RANGE (listened_at);

-- Auto-create monthly partitions for 2025–2027
DO $$
DECLARE y INT; m INT; s DATE; e DATE;
BEGIN
  FOR y IN 2025..2027 LOOP
    FOR m IN 1..12 LOOP
      s := make_date(y, m, 1);
      e := s + INTERVAL '1 month';
      EXECUTE format(
        'CREATE TABLE IF NOT EXISTS listening_history_%s_%s
         PARTITION OF listening_history FOR VALUES FROM (%L) TO (%L)',
        y, lpad(m::text,2,'0'), s, e);
    END LOOP;
  END LOOP;
END $$;

-- ─────────────────────────────────────────────────────────────────────────────
-- RECOMMENDATIONS
-- ─────────────────────────────────────────────────────────────────────────────

-- Nightly job writes similarity scores; app reads top-N per user
CREATE TABLE similarity (
    user_id     UUID  NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    song_id     UUID  NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    score       FLOAT NOT NULL,
    computed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, song_id)
);

-- ─────────────────────────────────────────────────────────────────────────────
-- SOCIAL — LISTENING PARTIES
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE listening_parties (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    host_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name            TEXT NOT NULL DEFAULT 'Mi Listening Party',
    invite_code     TEXT NOT NULL UNIQUE DEFAULT upper(left(gen_random_uuid()::text, 8)),
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    current_song_id UUID REFERENCES songs(id) ON DELETE SET NULL,
    position_s      NUMERIC(10,2) NOT NULL DEFAULT 0,
    started_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at        TIMESTAMPTZ
);

CREATE TABLE party_members (
    party_id  UUID NOT NULL REFERENCES listening_parties(id) ON DELETE CASCADE,
    user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    is_host   BOOLEAN NOT NULL DEFAULT FALSE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (party_id, user_id)
);

CREATE TABLE party_chat (
    id       UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    party_id UUID NOT NULL REFERENCES listening_parties(id) ON DELETE CASCADE,
    user_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    message  TEXT NOT NULL,
    reaction TEXT,
    sent_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE party_queue (
    party_id     UUID NOT NULL REFERENCES listening_parties(id) ON DELETE CASCADE,
    song_id      UUID NOT NULL REFERENCES songs(id) ON DELETE CASCADE,
    requested_by UUID REFERENCES users(id) ON DELETE SET NULL,
    position     INT  NOT NULL,
    played       BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (party_id, position)
);

-- Dropped: party_role enum (replaced by is_host boolean — simpler),
--          surrogate PKs where composite keys suffice, left_at (not needed),
--          added_at on party_queue

-- ─────────────────────────────────────────────────────────────────────────────
-- DJ MODE
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE dj_sessions (
    id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name          TEXT NOT NULL DEFAULT 'Mi Set',
    started_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    ended_at      TIMESTAMPTZ,
    is_saved      BOOLEAN NOT NULL DEFAULT FALSE,
    recording_url TEXT
);

CREATE TABLE dj_tracks (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id   UUID  NOT NULL REFERENCES dj_sessions(id) ON DELETE CASCADE,
    song_id      UUID  NOT NULL REFERENCES songs(id)        ON DELETE CASCADE,
    deck         CHAR(1) NOT NULL CHECK (deck IN ('A','B')),
    position     INT   NOT NULL,
    -- Tempo
    original_bpm NUMERIC(6,2),
    adjusted_bpm NUMERIC(6,2),
    -- EQ knobs (-12 to +12 dB)
    eq_low       NUMERIC(5,2) NOT NULL DEFAULT 0,
    eq_mid       NUMERIC(5,2) NOT NULL DEFAULT 0,
    eq_high      NUMERIC(5,2) NOT NULL DEFAULT 0,
    -- Mixer
    volume       NUMERIC(4,3) NOT NULL DEFAULT 1.0,
    crossfader   NUMERIC(4,3) NOT NULL DEFAULT 0.5,
    -- Cue / loop points (ms precision needed for DJ timing)
    cue_in_ms    INT, cue_out_ms  INT,
    loop_start_ms INT, loop_end_ms INT,
    played_at    TIMESTAMPTZ,
    added_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Dropped: filter_enabled (feature explicitly excluded in requirements)

-- ─────────────────────────────────────────────────────────────────────────────
-- NOTIFICATIONS
-- ─────────────────────────────────────────────────────────────────────────────

CREATE TABLE notifications (
    id        UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type      TEXT NOT NULL DEFAULT 'system',  -- new_release|listening_party|system|social
    title     TEXT NOT NULL,
    content   TEXT NOT NULL,
    is_read   BOOLEAN NOT NULL DEFAULT FALSE,
    deep_link TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Dropped: notification_type enum — TEXT is fine with a CHECK or app-level validation

-- ─────────────────────────────────────────────────────────────────────────────
-- SEARCH VIEW
-- ─────────────────────────────────────────────────────────────────────────────

CREATE VIEW search_index AS
    SELECT 'song'   AS entity_type, s.id AS entity_id,
           s.title  AS primary_text, a.name AS secondary_text,
           s.cover_url AS image_url, s.play_count AS popularity,
           s.search_vector AS sv
    FROM songs s JOIN artists a ON a.id = s.artist_id WHERE s.streamable
    UNION ALL
    SELECT 'artist', a.id, a.name, NULL, a.image_url,
           a.monthly_listeners, a.search_vector FROM artists a
    UNION ALL
    SELECT 'album', al.id, al.title, a.name, al.cover_url, 0, al.search_vector
    FROM albums al JOIN artists a ON a.id = al.artist_id
    UNION ALL
    SELECT 'playlist', p.id, p.name, u.display_name, p.cover_url,
           p.total_songs, p.search_vector
    FROM playlists p JOIN users u ON u.id = p.owner_id WHERE p.visibility = 'public';

-- ─────────────────────────────────────────────────────────────────────────────
-- INDEXES
-- ─────────────────────────────────────────────────────────────────────────────

-- Full-text
CREATE INDEX ON songs     USING GIN (search_vector);
CREATE INDEX ON artists   USING GIN (search_vector);
CREATE INDEX ON albums    USING GIN (search_vector);
CREATE INDEX ON playlists USING GIN (search_vector);

-- Trigram fuzzy
CREATE INDEX ON songs     USING GIN (title gin_trgm_ops);
CREATE INDEX ON artists   USING GIN (name  gin_trgm_ops);

-- Catalog
CREATE INDEX ON songs           (artist_id);
CREATE INDEX ON songs           (album_id);
CREATE INDEX ON songs           (file_id);
CREATE INDEX ON albums          (artist_id);
CREATE INDEX ON song_genres     (genre_id);
CREATE INDEX ON song_moods      (mood_id);
CREATE INDEX ON playlist_songs  (playlist_id, position);
CREATE INDEX ON liked_songs     (user_id, liked_at DESC);
CREATE INDEX ON downloads       (user_id, status);
CREATE INDEX ON user_queue      (user_id, position);
CREATE INDEX ON listening_history (user_id, listened_at DESC);
CREATE INDEX ON similarity      (user_id, score DESC);
CREATE INDEX ON dj_tracks       (session_id, position);
CREATE INDEX ON party_chat      (party_id, sent_at DESC);
CREATE INDEX ON notifications   (user_id, is_read, created_at DESC);
CREATE INDEX ON users           (active_mood_id);

-- ─────────────────────────────────────────────────────────────────────────────
-- TRIGGERS
-- ─────────────────────────────────────────────────────────────────────────────

-- updated_at helper (reused for all tables)
CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$;

CREATE TRIGGER t ON songs     BEFORE UPDATE FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER t ON playlists BEFORE UPDATE FOR EACH ROW EXECUTE FUNCTION set_updated_at();
CREATE TRIGGER t ON users     BEFORE UPDATE FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Keep playlist total_songs / total_duration_s in sync
CREATE OR REPLACE FUNCTION sync_playlist_stats()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE pid UUID := COALESCE(NEW.playlist_id, OLD.playlist_id);
BEGIN
    UPDATE playlists SET
        total_songs      = (SELECT COUNT(*)        FROM playlist_songs WHERE playlist_id = pid),
        total_duration_s = (SELECT COALESCE(SUM(s.duration_s), 0)
                            FROM playlist_songs ps JOIN songs s ON s.id = ps.song_id
                            WHERE ps.playlist_id = pid)
    WHERE id = pid;
    RETURN NULL;
END; $$;

CREATE TRIGGER t AFTER INSERT OR UPDATE OR DELETE ON playlist_songs
FOR EACH ROW EXECUTE FUNCTION sync_playlist_stats();

-- Increment play_count on completed listens
CREATE OR REPLACE FUNCTION inc_play_count()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.completed THEN
        UPDATE songs SET play_count = play_count + 1 WHERE id = NEW.song_id;
    END IF;
    RETURN NULL;
END; $$;

CREATE TRIGGER t AFTER INSERT ON listening_history
FOR EACH ROW EXECUTE FUNCTION inc_play_count();
