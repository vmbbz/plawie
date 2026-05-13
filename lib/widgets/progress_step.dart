import 'package:flutter/material.dart';
import '../app.dart';

class ProgressStep extends StatelessWidget {
  final int stepNumber;
  final String label;
  final bool isActive;
  final bool isComplete;
  final bool hasError;
  final double? progress;

  const ProgressStep({
    super.key,
    required this.stepNumber,
    required this.label,
    this.isActive = false,
    this.isComplete = false,
    this.hasError = false,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color circleColor;
    Widget circleChild;
    List<BoxShadow> shadows = [];

    if (hasError) {
      circleColor = theme.colorScheme.error;
      circleChild = const Icon(Icons.close, color: Colors.white, size: 16);
    } else if (isComplete) {
      circleColor = AppColors.statusGreen;
      circleChild = const Icon(Icons.check, color: Colors.black, size: 18);
      shadows = [
        BoxShadow(
          color: AppColors.statusGreen.withValues(alpha: 0.3),
          blurRadius: 10,
          spreadRadius: 2,
        )
      ];
    } else if (isActive) {
      circleColor = AppColors.statusGreen;
      circleChild = Padding(
        padding: const EdgeInsets.all(6.0),
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.black,
          value: progress,
        ),
      );
      shadows = [
        BoxShadow(
          color: AppColors.statusGreen.withValues(alpha: 0.5),
          blurRadius: 15,
          spreadRadius: 3,
        )
      ];
    } else {
      circleColor = isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05);
      circleChild = Text(
        '$stepNumber',
        style: TextStyle(
          color: isDark ? Colors.white70 : Colors.black54,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: circleColor,
                  shape: BoxShape.circle,
                  boxShadow: shadows,
                  border: Border.all(
                    color: (isActive || isComplete) 
                        ? AppColors.statusGreen 
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: circleChild,
              ),
              Expanded(
                child: Container(
                  width: 2,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  color: isComplete 
                      ? AppColors.statusGreen 
                      : (isDark ? Colors.white10 : Colors.black12),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 15,
                    letterSpacing: 0.5,
                    color: isActive
                        ? AppColors.statusGreen
                        : (isComplete ? Colors.white : (isDark ? Colors.white38 : Colors.black38)),
                  ),
                ),
                if (isActive)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(2),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: Colors.white.withValues(alpha: 0.05),
                            valueColor: const AlwaysStoppedAnimation(AppColors.statusGreen),
                          ),
                        ),
                        if (progress != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${(progress! * 100).toInt()}% complete',
                              style: TextStyle(
                                color: AppColors.statusGreen.withValues(alpha: 0.7),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                else
                  const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
