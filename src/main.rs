use std::fs::File;
use std::io::Read;
use std::path::PathBuf;
use std::time::Duration;

use anyhow::{anyhow, Context, Result};
use clap::Parser;
use colored::Colorize;
use image::GenericImageView;
use reqwest::blocking::Client;
use serde::Deserialize;

const BASE_URL: &str = "https://maitea.app";

#[derive(Debug, Default, Deserialize)]
#[serde(rename_all = "camelCase")]
struct FileConfig {
    access_token: Option<String>,
    score_count: Option<usize>,
    logo_size: Option<i32>,
}

#[derive(Debug, Parser)]
#[command(name = "maifetch")]
#[command(about = "a really lazy fetch tool for maitea")]
struct Cli {
    #[arg(short = 'a', short_alias = 't', long = "access-token", alias = "token")]
    access_token: Option<String>,

    #[arg(short = 'c', long = "config-file")]
    config_file: Option<PathBuf>,

    #[arg(short = 's', long = "score-count")]
    score_count: Option<usize>,

    #[arg(short = 'l', long = "logo-size")]
    logo_size: Option<i32>,
}

#[derive(Debug)]
struct Config {
    access_token: String,
    score_count: usize,
    logo_size: i32,
}

#[derive(Debug, Deserialize)]
struct ApiList<T> {
    data: T,
}

#[derive(Debug, Deserialize)]
struct ImageRef {
    png: String,
}

#[derive(Debug, Deserialize)]
struct ProfileOptions {
    icon: ImageRef,
}

#[derive(Debug, Deserialize)]
struct PlayStats {
    total: i32,
}

#[derive(Debug, Deserialize)]
struct Profile {
    id: i32,
    name: String,
    rating: i32,
    rating_highest: i32,
    level: i32,
    play_stats: PlayStats,
    options: ProfileOptions,
}

#[derive(Debug, Deserialize)]
struct LocalizedName {
    en: String,
}

#[derive(Debug, Deserialize)]
struct TrackInfo {
    name: LocalizedName,
}

#[derive(Debug, Deserialize)]
struct DifficultyLevel {
    value: String,
}

#[derive(Debug, Deserialize)]
struct Play {
    achievement_formatted: String,
    score_formatted: String,
    rank: String,
    full_combo_label: Option<String>,
    difficulty_level: DifficultyLevel,
    song: TrackInfo,
}

fn default_config_path() -> Result<PathBuf> {
    let dir = dirs::config_dir().ok_or_else(|| anyhow!("could not determine config directory"))?;
    Ok(dir.join("maifetch.json"))
}

fn load_file_config(path: &PathBuf) -> Result<FileConfig> {
    if !path.exists() {
        return Ok(FileConfig::default());
    }
    let mut file =
        File::open(path).with_context(|| format!("could not open {}", path.display()))?;
    let mut raw = String::new();
    file.read_to_string(&mut raw)?;
    Ok(
        serde_json::from_str(&raw)
            .with_context(|| format!("could not parse {}", path.display()))?,
    )
}

fn env_string(name: &str) -> Option<String> {
    std::env::var(name)
        .ok()
        .filter(|value| !value.trim().is_empty())
}

fn env_string_any(names: &[&str]) -> Option<String> {
    names.iter().find_map(|name| env_string(name))
}

fn env_parse<T: std::str::FromStr>(name: &str) -> Option<T> {
    env_string(name).and_then(|value| value.parse::<T>().ok())
}

fn env_parse_any<T: std::str::FromStr>(names: &[&str]) -> Option<T> {
    names.iter().find_map(|name| env_parse(name))
}

fn load_config() -> Result<Config> {
    let cli = Cli::parse();
    let config_path = cli
        .config_file
        .clone()
        .or_else(|| {
            env_string_any(&["MAITEA_CONFIG_FILE", "MAIFETCH_CONFIG_FILE"]).map(PathBuf::from)
        })
        .unwrap_or(default_config_path()?);
    let file_config = load_file_config(&config_path)?;

    let access_token = cli
        .access_token
        .or_else(|| env_string_any(&["MAITEA_TOKEN", "MAIFETCH_TOKEN"]))
        .or(file_config.access_token)
        .ok_or_else(|| anyhow!("access token is required"))?;

    let score_count = cli
        .score_count
        .or_else(|| env_parse_any(&["MAITEA_SCORE_COUNT", "MAIFETCH_SCORE_COUNT"]))
        .or(file_config.score_count)
        .unwrap_or(4);

    let logo_size = cli
        .logo_size
        .or_else(|| env_parse_any(&["MAITEA_LOGO_SIZE", "MAIFETCH_LOGO_SIZE"]))
        .or(file_config.logo_size)
        .unwrap_or(20);

    if score_count > 12 {
        return Err(anyhow!("score count cannot be higher than 12"));
    }

    Ok(Config {
        access_token,
        score_count,
        logo_size,
    })
}

struct ApiClient {
    token: String,
    http: Client,
}

impl ApiClient {
    fn new(token: String) -> Result<Self> {
        Ok(Self {
            token,
            http: Client::builder().timeout(Duration::from_secs(30)).build()?,
        })
    }

    fn get<T: for<'de> Deserialize<'de>>(&self, path: &str) -> Result<T> {
        let url = format!("{BASE_URL}{path}");
        let response = self
            .http
            .get(url)
            .bearer_auth(&self.token)
            .header("Content-Type", "application/json")
            .header("Accept", "application/json")
            .send()?
            .error_for_status()?;
        Ok(response.json()?)
    }

    fn profiles(&self) -> Result<Vec<Profile>> {
        Ok(self.get::<ApiList<Vec<Profile>>>("/api/v1/profiles")?.data)
    }

    fn plays(&self) -> Result<Vec<Play>> {
        Ok(self.get::<ApiList<Vec<Play>>>("/api/v1/plays")?.data)
    }
}

fn colour(value: &str) -> String {
    value.truecolor(72, 184, 200).to_string()
}

fn wide_to_normal(value: &str) -> String {
    value
        .chars()
        .map(|chr| {
            let code = chr as u32;
            if (0xFF01..=0xFF5E).contains(&code) {
                char::from_u32(code - 0xFEE0).unwrap_or(chr)
            } else {
                chr
            }
        })
        .collect()
}

fn difficulty_string(value: &str) -> &'static str {
    match value {
        "basic" => "BASIC",
        "advanced" => "ADVANCED",
        "expert" => "EXPERT",
        "master" => "MASTER",
        "remaster" => "Re:MASTER",
        _ => "UNKNOWN",
    }
}

fn rank_string(value: &str) -> &'static str {
    match value {
        "d" => "D",
        "c" => "C",
        "b" => "B",
        "bb" => "BB",
        "bbb" => "BBB",
        "a" => "A",
        "aa" => "AA",
        "aaa" => "AAA",
        "s" => "S",
        "sp" => "S+",
        "ss" => "SS",
        "ssp" => "SS+",
        "sss" => "SSS",
        "sssp" => "SSS+",
        _ => "UNKNOWN",
    }
}

fn create_info_strings(profile: &Profile, plays: &[Play], score_count: usize) -> Vec<String> {
    let name = wide_to_normal(&profile.name);
    let mut lines = vec![
        colour(&name),
        "-".repeat(name.chars().count()),
        format!("{}: {}", colour("ID"), profile.id),
        format!(
            "{}: {:.2} / {:.2}",
            colour("Rating"),
            profile.rating as f32 / 100.0,
            profile.rating_highest as f32 / 100.0
        ),
        format!("{}: {}", colour("Level"), profile.level),
        format!("{}: {}", colour("Total Credits"), profile.play_stats.total),
        format!("{}:", colour("Recent Scores")),
    ];

    for play in plays.iter().take(score_count) {
        let fc_label = play.full_combo_label.as_deref().unwrap_or("");
        lines.push(format!(
            "  {}  {}",
            play.song.name.en,
            difficulty_string(&play.difficulty_level.value)
        ));
        lines.push(format!(
            "  {} {}% {} {}",
            play.score_formatted,
            play.achievement_formatted,
            rank_string(&play.rank),
            fc_label
        ));
        lines.push(String::new());
    }

    lines
}

fn url_to_ascii(url: &str, size: i32) -> Result<String> {
    let bytes = Client::builder()
        .timeout(Duration::from_secs(30))
        .build()?
        .get(url)
        .send()?
        .error_for_status()?
        .bytes()?;
    let image = image::load_from_memory(&bytes)?;
    let width = (size * 2).max(1) as u32;
    let height = size.max(1) as u32;
    let resized = image.thumbnail_exact(width, height);
    let chars = [" ", ".", ":", "-", "=", "+", "*", "#", "%", "@"];
    let mut out = String::new();

    for y in 0..resized.height() {
        for x in 0..resized.width() {
            let pixel = resized.get_pixel(x, y);
            let [r, g, b, _] = pixel.0;
            let brightness = (0.2126 * r as f32 + 0.7152 * g as f32 + 0.0722 * b as f32) / 255.0;
            let idx = ((1.0 - brightness) * (chars.len() - 1) as f32).round() as usize;
            out.push_str(chars[idx].truecolor(r, g, b).to_string().as_str());
        }
        out.push('\n');
    }

    Ok(out)
}

fn print_combined(info_lines: &[String], logo_lines: &[&str], logo_size: i32) {
    let max_len = info_lines.len().max(logo_lines.len());
    let blank_logo = " ".repeat((logo_size * 2).max(0) as usize);

    for i in 0..max_len {
        let logo = if i < logo_lines.len() {
            logo_lines[i]
        } else {
            &blank_logo
        };
        let info = if i < info_lines.len() {
            &info_lines[i]
        } else {
            ""
        };
        println!("{logo}  {info}");
    }
}

fn output(plays: &[Play], profile: &Profile, logo_size: i32, score_count: usize) -> Result<()> {
    let info_lines = create_info_strings(profile, plays, score_count);

    if logo_size > 0 {
        let logo = url_to_ascii(&profile.options.icon.png, logo_size)?;
        let logo_lines = logo.lines().collect::<Vec<_>>();
        print_combined(&info_lines, &logo_lines, logo_size);
    } else {
        println!("{}", info_lines.join("\n"));
    }

    Ok(())
}

fn main() {
    if let Err(err) = run() {
        println!("{err}");
    }
}

fn run() -> Result<()> {
    let config = load_config()?;
    let client = ApiClient::new(config.access_token)?;
    let profiles = client.profiles()?;

    let Some(profile) = profiles.first() else {
        println!("No profiles found");
        return Ok(());
    };

    let plays = client.plays()?;
    output(&plays, profile, config.logo_size, config.score_count)
}
