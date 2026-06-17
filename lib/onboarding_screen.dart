import 'package:flutter/material.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onOnboardingComplete;
  const OnboardingScreen({super.key, required this.onOnboardingComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.orange.shade50,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: const [
                  OnboardPage(
                    title: "Welcome to SmartClimate",
                    description: "Monitor surrounding micro-climates, temperature variations, and high heat warnings instantly.",
                    icon: Icons.wb_sunny_rounded,
                  ),
                  OnboardPage(
                    title: "Community Driven Feed",
                    description: "Share real-time climate conditions and check live neighborhood feedback from active locals.",
                    icon: Icons.people_alt,
                  ),
                  OnboardPage(
                    title: "Stay Hydrated & Safe",
                    description: "Get personalized daily reminders to drink water and follow wellness checklists during peak UV hours.",
                    icon: Icons.local_drink_rounded,
                  ),
                ],
              ),
            ),
            // Bottom Controls Row
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: widget.onOnboardingComplete,
                    child: const Text("SKIP", style: TextStyle(color: Colors.grey)),
                  ),
                  // Simple Page Dots Indicators
                  Row(
                    children: List.generate(3, (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 12 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? Colors.orange : Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      if (_currentPage < 2) {
                        _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeIn
                        );
                      } else {
                        widget.onOnboardingComplete();
                      }
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                    child: Text(_currentPage == 2 ? "GET STARTED" : "NEXT"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class OnboardPage extends StatelessWidget {
  final String title; final String description; final IconData icon;
  const OnboardPage({super.key, required this.title, required this.description, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 120, color: Colors.orange.shade700),
          const SizedBox(height: 40),
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Text(description, style: TextStyle(fontSize: 14, color: Colors.grey.shade600), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}