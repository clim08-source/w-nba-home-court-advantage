library(tidyverse)
library(wehoop)
library(hoopR)
 
# ---- 1. Load game results ---------------------------------------------------
 
seasons <- 2021:2025
 
wnba <- load_wnba_schedule(seasons = seasons)
nba  <- load_nba_schedule(seasons = seasons)
 
# Keep completed regular-season games at a real home arena
clean_games <- function(df, league) {
  df |>
    filter(season_type == 2, !neutral_site, !is.na(home_score)) |>
    transmute(
      league, season,
      home   = home_display_name,
      away   = away_display_name,
      margin = as.numeric(home_score) - as.numeric(away_score)
    )
}
 
games <- bind_rows(clean_games(wnba, "WNBA"), clean_games(nba, "NBA"))
 
# ---- 2. League-wide home court advantage ------------------------------------
 
league_hca <- games |>
  group_by(league) |>
  summarise(
    n               = n(),
    avg_home_margin = mean(margin),
    home_win_pct    = mean(margin > 0),
    se              = sd(margin) / sqrt(n),
    ci_low          = avg_home_margin - 1.96 * se,
    ci_high         = avg_home_margin + 1.96 * se
  )
 
league_hca
 
# ---- 3. Shared-arena teams --------------------------------------------------
# Check names with unique(games$home) if a team is missing.
 
arenas <- tribble(
  ~home,                    ~arena,
  "Phoenix Mercury",        "PHX Arena",
  "Phoenix Suns",           "PHX Arena",
  "Minnesota Lynx",         "Target Center",
  "Minnesota Timberwolves", "Target Center",
  "Indiana Fever",          "Gainbridge Fieldhouse",
  "Indiana Pacers",         "Gainbridge Fieldhouse",
  "New York Liberty",       "Barclays Center",
  "Brooklyn Nets",          "Barclays Center",
  "Los Angeles Sparks",     "Crypto.com Arena",
  "Los Angeles Lakers",     "Crypto.com Arena"
)
 
# WNBA games are 40 minutes, so scale margins to 48 for a fair comparison
arena_hca <- games |>
  inner_join(arenas, by = "home") |>
  mutate(margin48 = if_else(league == "WNBA", margin * 48 / 40, margin)) |>
  group_by(arena, league) |>
  summarise(
    n   = n(),
    hca = mean(margin48),
    se  = sd(margin48) / sqrt(n),
    .groups = "drop"
  )
 
arena_hca
 
# ---- 4. Chart ---------------------------------------------------------------
 
league_colors <- c(WNBA = "#eb6834", NBA = "#2a78d6")
 
p <- ggplot(arena_hca, aes(x = hca, y = reorder(arena, hca), color = league)) +
  geom_vline(xintercept = 0, color = "grey60") +
  geom_line(aes(group = arena), color = "grey80", linewidth = 1) +
  geom_errorbarh(aes(xmin = hca - 1.96 * se, xmax = hca + 1.96 * se),
                 height = 0.15, linewidth = 0.6, alpha = 0.6) +
  geom_point(size = 3.5) +
  scale_color_manual(values = league_colors) +
  labs(
    title    = "Home court advantage in shared arenas",
    subtitle = "Average home margin per 48 minutes, 2021–2025 regular season, with 95% CIs",
    x        = "Home margin (points per 48 min)", y = NULL, color = NULL,
    caption  = "Data: ESPN via wehoop / hoopR. WNBA margins scaled from 40 to 48 minutes."
  ) +
  theme_minimal(base_size = 13) +
  theme(
    legend.position    = "top",
    panel.grid.major.y = element_blank(),
    panel.grid.minor   = element_blank(),
    plot.title         = element_text(face = "bold")
  )
 
p
 
dir.create("figures", showWarnings = FALSE)
ggsave("figures/arena_hca.png", p, width = 9, height = 5.5, dpi = 300, bg = "white")