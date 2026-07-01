# Shared ECC (everything-claude-code) asset pack for the coding-agent module.
#
# One fetch (pinned by rev) provides the skills/agents/commands/rules used by
# *both* agents: Claude reads them natively from ~/.claude/*, and pi reads the
# same ~/.claude/skills via its `settings.skills` (see ./default.nix). Adding or
# bumping the pack here updates both agents at once — the same single-source
# principle as the shared mcp.json.
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.xsfx.codingAgent;

  # Rev: 2026-07-01 — run `nixos-rebuild` once, paste the correct hash from the error.
  # Upstream renamed the repo everything-claude-code → ECC (same owner).
  ecc-src = pkgs.fetchFromGitHub {
    owner = "affaan-m";
    repo = "ECC";
    rev = "81af40761939056ab3dc54732fd4f562a27309d0";
    hash = "sha256-qTBoRTk+6/RG82QtPuhq/DSKeDXczUkU70Sn23gDFDs=";
  };

  # ECC rules plus our visual-context protocol appended.
  customRules = pkgs.runCommand "custom-rules" { } ''
        mkdir -p $out
        cp -r ${ecc-src}/rules/* $out/
        cat <<EOF > $out/visual-context.md
    # Visual Context Protocol
    Whenever the user runs the \`crush-img\` command or mentions a "pasted image", "clipboard image", or "screenshot", the assistant MUST immediately attempt to \`view\` the file at /run/user/1000/crush_clipboard.png.
    Do not wait for the user to explicitly ask what is in the image.
    Analyze the visual evidence to provide immediate, context-aware feedback or debugging help.
    EOF
  '';

  # Skills loaded every session on this host. The full ECC set is ~277 skills
  # (~27k tokens of "menu" injected into every prompt) — fatal for the local
  # offline model's 32k window and wasteful/selection-dulling online. Keep a
  # small stack-matched set here; the full catalog stays reachable (but NOT
  # auto-loaded) under ~/.claude/skill-library via the router below. Re-run the
  # `agent-sort` skill when the stack changes to re-propose this list.
  dailySkills = [
    # stack — matched to this repo (git repo, some Go, fish-heavy, configs MCP)
    "git-workflow"
    "golang-patterns"
    "terminal-ops"
    "coding-standards"
    "mcp-server-patterns"
    # discipline — high-leverage and stack-agnostic
    "verification-loop"
    "search-first"
    # meta — keep only the re-tuner loaded; the rest live in the library
    "agent-sort"
  ];

  # Router that tells the agent the parked library exists and how to pull from it.
  skillLibraryRouter = pkgs.writeText "skill-library-router.md" ''
    ---
    name: skill-library
    description: Index of ECC skills kept installed but NOT auto-loaded for this repo. Use when a task needs a skill outside the daily git/go/shell set (web, mobile, backend frameworks, databases, domain, media, agent-meta). Full skill bodies live under ~/.claude/skill-library/.
    ---
    # Skill Library (on-demand)

    Only a small daily set loads automatically. The full ECC catalog lives at
    `~/.claude/skill-library/<name>/SKILL.md` and is NOT auto-loaded. Read one
    when its keywords match the task:

    - web/frontend: react, vue, angular, nuxt, next, tailwind, motion, design-system
    - mobile: swift, flutter, kotlin, android, react-native, ios
    - backend: django, laravel, spring, fastapi, quarkus, nestjs
    - databases: postgres, mysql, clickhouse, redis, prisma
    - agent-meta: autonomous-loops, agent-architecture-audit, continuous-learning
    - domain/media: logistics, healthcare, marketing, manim, video, scientific

    To use one: read `~/.claude/skill-library/<name>/SKILL.md`, then follow it.
  '';

  dailySkillsDir = pkgs.runCommand "daily-skills" { } ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (s: "cp -r ${ecc-src}/skills/${s} $out/${s}") dailySkills}
    mkdir -p $out/skill-library
    cp ${skillLibraryRouter} $out/skill-library/SKILL.md
  '';
in
lib.mkIf cfg.enable {
  home-manager.users.${cfg.user}.home.file = {
    ".claude/agents".source = "${ecc-src}/agents";
    ".claude/commands".source = "${ecc-src}/commands";
    ".claude/rules".source = customRules;
    # Curated daily set (+ skill-library router); full catalog parked below.
    ".claude/skills".source = dailySkillsDir;
    ".claude/skill-library".source = "${ecc-src}/skills";
  };
}
