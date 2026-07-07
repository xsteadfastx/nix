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

  # Rule sets to install under ~/.claude/rules (the harness auto-loads these
  # into every prompt). ECC ships 22 language dirs (~280 KB); copying them all
  # is dead weight and a latent token risk. Keep only what this machine uses.
  # `common` is mandatory — the other sets link to ../common/*.md.
  ruleSets = [
    "common" # language-agnostic base (git, testing, security, code-review, …)
    "golang" # Go stack
  ];

  # Selected ECC rule sets.
  customRules = pkgs.runCommand "custom-rules" { } ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (r: "cp -r ${ecc-src}/rules/${r} $out/${r}") ruleSets}
    cp ${ecc-src}/rules/README.md $out/README.md
  '';

  # Skills loaded every session on this host. The full ECC set is ~277 skills
  # (~27k tokens of "menu" injected into every prompt) — fatal for the local
  # offline model's 32k window and wasteful/selection-dulling online. Keep a
  # small stack-matched set here; the full catalog stays reachable (but NOT
  # auto-loaded) under ~/.claude/skill-library via the router below. Re-run the
  # `agent-sort` skill when the stack changes to re-propose this list.
  dailySkills = [
    # --- STACK (Git & System) ---
    # Language skills (golang-patterns, python-patterns, …) live in the library
    # and load on-demand via the router below — this host is Nix/infra-first, so
    # no language skill is worth the per-turn cost in every session.
    "git-workflow" # Clean commits, branching strategies and git hygiene
    "terminal-ops" # Efficient terminal commands and shell operations (fish-heavy)
    "coding-standards" # Cross-cutting architecture and coding guidelines

    # --- DISCIPLINE & QUALITY (Good code) ---
    # NOTE: TDD + verification discipline now comes from obra/superpowers
    # (test-driven-development, verification-before-completion), loaded as a pi
    # extension / Claude plugin — see ./superpowers.nix. The ECC equivalents
    # (tdd-workflow, verification-loop) were dropped here to avoid running two
    # lineages that preach the same discipline (dulls selection, burns tokens).

    # --- RESEARCH & EXPERTISE (Search first, then web) ---
    # search-first is the generic ECC guard; research-first is our own
    # host-specific version (repo-authored, see ./skills/research-first.md)
    # that names the exact channels available here: rg through this repo,
    # nixpkgs/home-manager option search, the nixos + context7 MCP servers,
    # and pi's web_search/web_visit. Both load daily — search-first is the
    # principle, research-first is the playbook for *this* machine.
    "search-first" # Generic ECC guard: prevents reinventing the wheel

    # --- META ---
    "agent-sort" # Keeps the setup clean and proposes optimizations
  ];

  # Router that tells the agent the parked library exists and how to pull from it.
  skillLibraryRouter = pkgs.writeText "skill-library-router.md" ''
    ---
    name: skill-library
    description: Index of ECC skills kept installed but NOT auto-loaded for this repo. Use when a task needs a skill outside the daily git/shell set — language idioms (Go, Python, Rust, …), web, mobile, backend frameworks, databases, domain, media, agent-meta. Full skill bodies live under ~/.claude/skill-library/.
    ---
    # Skill Library (on-demand)

    Only a small daily set loads automatically. The full ECC catalog lives at
    `~/.claude/skill-library/<name>/SKILL.md` and is NOT auto-loaded. When the
    task matches one of these, read that exact `<name>/SKILL.md` and follow it.
    Names in parentheses are the exact skill dirs to read.

    - languages — read the matching one when writing/reviewing that language:
      - go: golang-patterns, golang-testing
      - python: python-patterns, python-testing
      - rust: rust-patterns, rust-testing
      - c/c++: cpp-coding-standards, cpp-testing
      - c#/.net: dotnet-patterns, csharp-testing
      - java: java-coding-standards, springboot-patterns, quarkus-patterns, jpa-patterns
      - kotlin: kotlin-patterns, kotlin-coroutines-flows, kotlin-testing
      - swift: swiftui-patterns, swift-concurrency-6-2, swift-protocol-di-testing
      - perl: perl-patterns, perl-testing, perl-security
    - web/frontend: react (react-patterns), vue (vue-patterns), nuxt (nuxt4-patterns), frontend-patterns, motion-patterns, vite-patterns
    - mobile: swiftui-patterns, dart-flutter-patterns, react-native-patterns, compose-multiplatform-patterns
    - backend: django-patterns, laravel-patterns, springboot-patterns, fastapi-patterns, quarkus-patterns, nestjs-patterns, backend-patterns
    - databases/orm: postgres-patterns, mysql-patterns, redis-patterns, prisma-patterns, jpa-patterns
    - infra/deploy: docker-patterns, kubernetes-patterns, deployment-patterns
    - agent-meta: autonomous-loops, agent-architecture-audit, continuous-learning
    - domain/media: logistics, healthcare, marketing, manim, video, scientific

    To use one: read `~/.claude/skill-library/<name>/SKILL.md`, then follow it.
  '';

  # Custom skills authored in this repo (not from ECC). Each becomes a
  # <name>/SKILL.md dir under ~/.claude/skills, so they are auto-loaded every
  # session by both Claude and pi (which reads ~/.claude/skills — see
  # ./default.nix). Keep these tight and host-specific: anything generic
  # belongs upstream in ECC and arrives via `dailySkills` instead.
  customSkills = {
    research-first = builtins.readFile ./skills/research-first.md;
  };

  customSkillsDir = pkgs.runCommand "custom-skills" { } ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (
      name:
      "mkdir -p $out/${name} && cp ${
        pkgs.writeText "${name}-SKILL.md" customSkills.${name}
      } $out/${name}/SKILL.md"
    ) (builtins.attrNames customSkills)}
  '';

  dailySkillsDir = pkgs.runCommand "daily-skills" { } ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (s: "cp -r ${ecc-src}/skills/${s} $out/${s}") dailySkills}
    # Merge repo-authored skills alongside the ECC daily set.
    cp -r ${customSkillsDir}/* $out/
    mkdir -p $out/skill-library
    cp ${skillLibraryRouter} $out/skill-library/SKILL.md
  '';

  # Agents (subagents) that Claude may spawn. Unlike skills there is NO
  # on-demand router: Claude only sees agents physically in ~/.claude/agents,
  # and injects every one's name+description into *every* prompt. The full ECC
  # set is 67 agents (~4k tokens of roster per turn), so curate to a lean,
  # stack-matched set. The full catalog stays parked (not auto-loaded) under
  # ~/.claude/agent-library for reference; adding one back means listing it
  # here and rebuilding (parked agents cannot be spawned).
  dailyAgents = [
    # --- STACK (Go) ---
    "go-reviewer" # Idiomatic Go review: concurrency, error handling, perf
    "go-build-resolver" # Fix Go build/vet/lint failures with minimal diffs

    # --- REVIEW GATES ---
    "code-reviewer" # General quality/maintainability review after edits
    "security-reviewer" # Secrets, injection, OWASP checks before commits

    # --- PLANNING & MAINTENANCE ---
    "planner" # Implementation planning for complex features/refactors
    "refactor-cleaner" # Dead-code/duplication cleanup
    "doc-updater" # Keep docs/codemaps in sync after changes
  ];

  dailyAgentsDir = pkgs.runCommand "daily-agents" { } ''
    mkdir -p $out
    ${lib.concatMapStringsSep "\n" (a: "cp ${ecc-src}/agents/${a}.md $out/${a}.md") dailyAgents}
  '';
in
lib.mkIf cfg.enable {
  home-manager.users.${cfg.user}.home.file = {
    # Curated daily agent set; full catalog parked (not auto-loaded) below.
    ".claude/agents".source = dailyAgentsDir;
    ".claude/agent-library".source = "${ecc-src}/agents";
    ".claude/commands".source = "${ecc-src}/commands";
    ".claude/rules".source = customRules;
    # Curated daily set (+ skill-library router); full catalog parked below.
    ".claude/skills".source = dailySkillsDir;
    ".claude/skill-library".source = "${ecc-src}/skills";
  };
}
