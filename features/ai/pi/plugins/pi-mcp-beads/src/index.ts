import { startBeadsMcpServer } from "./mcpServer";

async function main(): Promise<void> {
    await startBeadsMcpServer();
}

main().catch((error: unknown) => {
    const message = error instanceof Error ? error.message : String(error);
    process.stderr.write(`pi-mcp-beads failed to start: ${message}\n`);
    process.exit(1);
});
