import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:offline_first_app/providers/lesson_provider.dart';
import 'package:offline_first_app/providers/quiz_provider.dart';
import 'package:offline_first_app/screens/student_dashboard.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/classroom_provider.dart';
import 'providers/activity_provider.dart';
import 'models/user.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/teacher_dashboard.dart';
import 'modules/basic_operators/addition/addition_screen.dart';
import 'modules/basic_operators/addition/lesson_list_screen.dart';
import 'modules/basic_operators/addition/quiz_screen.dart';
import 'modules/basic_operators/addition/game_screen.dart';
import 'modules/basic_operators/addition/mock_data.dart';
import 'modules/basic_operators/basic_operations_dashboard.dart';
import 'modules/basic_operators/subtraction/subtraction_screen.dart';
import 'modules/basic_operators/subtraction/widgets/subtraction_lessons_screen.dart';
import 'modules/basic_operators/subtraction/widgets/subtraction_quiz_screen.dart';
import 'modules/basic_operators/subtraction/widgets/subtraction_games_screen.dart';
import 'modules/basic_operators/multiplication/multiplication_screen.dart';
import 'modules/basic_operators/multiplication/widgets/multiplication_lessons_screen.dart';
import 'modules/basic_operators/multiplication/widgets/multiplication_quiz_screen.dart';
import 'modules/basic_operators/multiplication/widgets/multiplication_games_screen.dart';
import 'modules/basic_operators/division/division_screen.dart';
import 'modules/basic_operators/division/widgets/division_lessons_screen.dart';
import 'modules/basic_operators/division/widgets/division_quiz_screen.dart';
import 'modules/basic_operators/division/widgets/division_games_screen.dart';

const String supabaseUrl = 'https://iblysqwclgpkijsxfgif.supabase.co';
const String supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlibHlzcXdjbGdwa2lqc3hmZ2lmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY4ODkzMzUsImV4cCI6MjA3MjQ2NTMzNX0.QjrhspglPRecKsXQ0XHswqHyvvQuOymsuh1xUGrT5xE';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => ClassroomProvider()),
        ChangeNotifierProvider(create: (_) => LessonProvider()),
        ChangeNotifierProvider(create: (_) => QuizProvider()),
        ChangeNotifierProvider(create: (_) => ActivityProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'PracPro',
        theme: ThemeData(
          primarySwatch: Colors.blue,
          useMaterial3: true,
          fontFamily: 'Roboto',
        ),
        home: const AuthWrapper(),
        routes: {
          '/welcome': (context) => const WelcomeScreen(),
          '/home': (context) => const HomeScreen(),
          '/profile': (context) => const ProfileScreen(),
          '/basic_operations': (context) => const BasicOperationsDashboard(),
          '/addition': (context) => const AdditionScreen(),
          '/addition/lessons': (context) => const LessonListScreen(classroomId: '',),
          '/addition/quiz': (context) {
            final auth = Provider.of<AuthProvider>(context, listen: false);
            final userId = auth.currentUser!.id;
            final quizId = additionLessons[0]['id'] ??
                "placeholder_addition_quiz";
            return QuizScreen(
              questions: additionLessons[0]['quiz'].cast<Map<String, dynamic>>(),
              quizId: quizId,
              userId: userId,
            );
          },
          '/addition/games': (context) => const GameScreen(),
          '/subtraction': (context) => const SubtractionScreen(),
          '/subtraction/lessons': (context) =>
          const SubtractionLessonsScreen(),
          '/subtraction/quiz': (context) =>
          const SubtractionQuizScreen(questions: []),
          '/subtraction/games': (context) => const SubtractionGamesScreen(),
          '/multiplication': (context) => const MultiplicationScreen(),
          '/multiplication/lessons': (context) =>
          const MultiplicationLessonsScreen(),
          '/multiplication/quiz': (context) =>
          const MultiplicationQuizScreen(),
          '/multiplication/games': (context) =>
          const MultiplicationGamesScreen(),
          '/division': (context) => const DivisionScreen(),
          '/division/lessons': (context) => const DivisionLessonsScreen(),
          '/division/quiz': (context) => const DivisionQuizScreen(),
          '/division/games': (context) => const DivisionGamesScreen(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        if (authProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (!authProvider.isAuthenticated || authProvider.currentUser == null) {
          return const WelcomeScreen();
        }

        final user = authProvider.currentUser!;
        if (user.userType == UserType.teacher) {
          return TeacherDashboard();
        } else {
          return StudentDashboard();
        }
      },
    );
  }
}
