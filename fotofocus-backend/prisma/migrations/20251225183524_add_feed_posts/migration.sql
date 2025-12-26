-- DropIndex
DROP INDEX "PostLike_postId_idx";

-- CreateIndex
CREATE INDEX "Post_createdAt_idx" ON "Post"("createdAt");
