/// Small, deterministic WorkLog help answers for when the assistant service is
/// slow or unavailable. This never creates, edits, or deletes app data.
class OfflineAssistantResponder {
  const OfflineAssistantResponder._();

  static String? replyTo(String message, {bool onlyIfHelp = false}) {
    final text = message.trim().toLowerCase();
    if (text.isEmpty) return null;

    final asksForHelp = RegExp(
      r'\b(hi|hello|hey|salam|assalam|how|where|what|help|kaise|kahan|kya|batao|samjhao|guide)\b',
    ).hasMatch(text);
    if (onlyIfHelp && !asksForHelp) return null;

    if (RegExp(r'^(hi|hello|hey|salam|assalam ?o ?alaikum)[!. ]*$')
        .hasMatch(text)) {
      return 'Hello! I can help you find WorkLog features. AI actions need an internet connection.';
    }
    if (RegExp(r'\b(work ?log|work entry|entry|hours|kaam)\b').hasMatch(text)) {
      return 'Work entry add karne ke liye Home ya Work Log kholen, + tap karein, task, hours aur date bhar kar Save karein.';
    }
    if (RegExp(r'\b(income|expense|kharcha|earning|finance|payment)\b')
        .hasMatch(text)) {
      return 'Income ya expense ke liye Finance kholen aur + action choose karein. Amount, currency, date aur category/client check karke Save karein.';
    }
    if (RegExp(r'\b(client|customer|project|invoice)\b').hasMatch(text)) {
      return 'Clients tab mein client kholen. Wahan project add hota hai; project ke invoice actions se PDF download ya online link share kar sakte hain.';
    }
    if (RegExp(r'\b(reminder|yaad|notification)\b').hasMatch(text)) {
      return 'Reminder add karne ke liye Reminders kholen, + tap karein, title aur date/time set karke Save karein.';
    }
    if (RegExp(r'\b(currency|currencies|pkr|usd|aud|rupee|dollar)\b')
        .hasMatch(text)) {
      return 'Default display currency Profile → Preferences → Select Currency mein badal sakte hain. Purane transactions apni original currency mein rehte hain.';
    }
    if (RegExp(r'\b(analytics|report|trend|statistics|stats)\b')
        .hasMatch(text)) {
      return 'Finance → Analytics mein daily, weekly aur monthly income/spending trends dekh sakte hain.';
    }
    if (RegExp(r'\b(dark ?mode|theme|appearance)\b').hasMatch(text)) {
      return 'Theme Profile → Preferences mein Light, Dark ya Auto select kar sakte hain.';
    }
    if (RegExp(r'\b(gym|workout|nutrition|meal|calorie)\b').hasMatch(text)) {
      return 'Gym tab mein workout tracking, meals aur fitness details manage hoti hain.';
    }

    if (asksForHelp) {
      return 'Offline help: Home par overview, Work Log mein entries, Clients mein projects, Finance mein income/expenses, aur Profile mein preferences milti hain.';
    }
    return null;
  }
}
