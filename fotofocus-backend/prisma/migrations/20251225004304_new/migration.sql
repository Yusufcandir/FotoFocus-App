/*
  Warnings:

  - A unique constraint covering the columns `[userId,photoId]` on the table `Rating` will be added. If there are existing duplicate values, this will fail.

*/
-- DropIndex
DROP INDEX "Rating_photoId_userId_key";

-- CreateIndex
CREATE UNIQUE INDEX "Rating_userId_photoId_key" ON "Rating"("userId", "photoId");
