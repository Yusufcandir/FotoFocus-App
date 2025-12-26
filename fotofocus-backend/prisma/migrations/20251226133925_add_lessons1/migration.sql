/*
  Warnings:

  - You are about to drop the column `content` on the `Lesson` table. All the data in the column will be lost.
  - You are about to drop the column `summary` on the `Lesson` table. All the data in the column will be lost.
  - Added the required column `body` to the `Lesson` table without a default value. This is not possible if the table is not empty.

*/
-- AlterTable
ALTER TABLE "Lesson" DROP COLUMN "content",
DROP COLUMN "summary",
ADD COLUMN     "body" TEXT NOT NULL,
ADD COLUMN     "imageUrl" TEXT;
