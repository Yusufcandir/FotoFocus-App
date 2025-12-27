import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/challenge_provider.dart';
import '../../data/models/challenge.dart';
import '../../core/constants.dart';
import 'create_challenge_screen.dart';

class ChallengesScreen extends StatefulWidget {
  const ChallengesScreen({super.key});

  @override
  State<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends State<ChallengesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = "";

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      context.read<ChallengeProvider>().loadChallenges();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _resolveImageUrl(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    if (raw.startsWith('http://') || raw.startsWith('https://')) return raw;

    return "${AppConstants.baseUrl}$raw";
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ChallengeProvider>();

    final String q = _query.trim().toLowerCase();
    final List<Challenge> filtered = q.isEmpty
        ? p.challenges
        : p.challenges.where((c) => c.title.toLowerCase().contains(q)).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => context.read<ChallengeProvider>().loadChallenges(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    const Text(
                      "Weekly Challenges",
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.add_rounded),
                      onPressed: () {
                        Navigator.pushNamed(context, "/challenge-create");
                      },
                    ),
                  ],
                ),
              ),

              // ✅ Search bar (added)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: "Search challenges...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                  ),
                ),
              ),

              if (p.loading)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (p.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: Center(
                    child: Text(
                      p.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                )
              else if (p.challenges.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: Center(child: Text("No challenges yet")),
                )
              else if (filtered.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 30),
                  child: Center(child: Text("No results")),
                )
              else
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: filtered.length,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.25,
                  ),
                  itemBuilder: (context, i) {
                    final Challenge c = filtered[i];
                    final cover = _resolveImageUrl(c.coverUrl);

                    return InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () {
                        // ✅ your main.dart route expects Challenge object
                        Navigator.pushNamed(
                          context,
                          "/challenge-detail",
                          arguments: c,
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(18),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (cover.isNotEmpty)
                              Image.network(
                                cover,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: Colors.black12,
                                  alignment: Alignment.center,
                                  child: const Icon(Icons.broken_image,
                                      color: Colors.black26),
                                ),
                              )
                            else
                              Container(color: Colors.black12),

                            // dark gradient
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withOpacity(0.05),
                                    Colors.black.withOpacity(0.55),
                                  ],
                                ),
                              ),
                            ),

                            // title
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 10,
                              child: Text(
                                c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
