import { spawn } from "child_process";
import * as fs from "fs";
import * as path from "path";

const REVIEWS_REPO = "git@github.com:wldandan/chess-reviews-summary.git";
const REVIEWS_DIR = path.join(process.env.HOME || "~", ".openclaw", "chess-reviews-summary");
const WORKSPACE_MEMORY = path.join(process.env.HOME || "~", ".openclaw", "workspace-chess-ai-coach", "memory");
const ANALYSES_DIR = path.join(process.env.HOME || "~", ".openclaw", "workspace-chess-ai-coach", "analyses");

interface MessageEvent {
  type: string;
  action: string;
  context: {
    to?: string;
    content: string;
    success?: boolean;
    channelId?: string;
  };
  messages: string[];
}

const handler = async (event: MessageEvent) => {
  // Only process outbound messages
  if (event.type !== "message" || event.action !== "sent") {
    return;
  }

  // Check if this is a chess review (contains analysis indicators)
  const content = event.context.content || "";
  const isReview = content.includes("📊") ||
                   content.includes("棋局概览") ||
                   content.includes("关键失误") ||
                   content.includes("亮点时刻");

  if (!isReview) {
    return;
  }

  console.log("[review-sync] Chess review detected, syncing...");

  // Sync the reviews
  await syncReviews();
};

async function syncReviews(): Promise<void> {
  return new Promise((resolve, reject) => {
    // Check if reviews repo exists, clone if not
    const repoExists = fs.existsSync(path.join(REVIEWS_DIR, ".git"));

    const cloneOrPull = () => {
      const git = spawn("git", repoExists
        ? ["-C", REVIEWS_DIR, "pull", "--rebase", "origin", "main"]
        : ["clone", REVIEWS_REPO, REVIEWS_DIR]
      );

      git.on("close", (code) => {
        if (code !== 0) {
          console.error("[review-sync] Git operation failed");
          reject(new Error(`Git exited with code ${code}`));
          return;
        }
        copyAndPush();
      });
    };

    const copyAndPush = () => {
      // Copy memory files to reviews repo
      if (!fs.existsSync(WORKSPACE_MEMORY)) {
        console.log("[review-sync] No memory directory found");
        resolve();
        return;
      }

      const files = fs.readdirSync(WORKSPACE_MEMORY).filter(f => f.endsWith(".md"));

      if (files.length === 0) {
        console.log("[review-sync] No review files to sync");
        resolve();
        return;
      }

      for (const file of files) {
        const src = path.join(WORKSPACE_MEMORY, file);
        const dest = path.join(REVIEWS_DIR, file);
        fs.copyFileSync(src, dest);
        console.log(`[review-sync] Copied: ${file}`);
      }

      // Commit and push
      const gitAdd = spawn("git", ["-C", REVIEWS_DIR, "add", "."]);
      gitAdd.on("close", () => {
        const date = new Date().toISOString().split("T")[0];
        const gitCommit = spawn("git", ["-C", REVIEWS_DIR, "commit", "-m", `Sync reviews ${date}`]);
        gitCommit.on("close", (code) => {
          if (code !== 0) {
            console.log("[review-sync] Nothing to commit");
            resolve();
            return;
          }
          const gitPush = spawn("git", ["-C", REVIEWS_DIR, "push", "origin", "main"]);
          gitPush.on("close", (pushCode) => {
            if (pushCode === 0) {
              console.log("[review-sync] Reviews synced successfully!");
            } else {
              console.error("[review-sync] Push failed");
            }
            resolve();
          });
        });
      });
    };

    cloneOrPull();
  });
}

export default handler;
