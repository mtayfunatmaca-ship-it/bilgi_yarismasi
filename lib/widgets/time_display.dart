import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Gerekirse tarih formatı için

// Sınav durumlarını buraya da alalım
enum ExamStatus { upcoming, active, finished, unknown }

class TimeDifferenceDisplay extends StatefulWidget {
  final DateTime? startTime;
  final DateTime? endTime;
  final ExamStatus status;

  const TimeDifferenceDisplay({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.status,
  });

  @override
  State<TimeDifferenceDisplay> createState() => _TimeDifferenceDisplayState();
}

class _TimeDifferenceDisplayState extends State<TimeDifferenceDisplay> {
  Timer? _timer;
  Duration _difference = Duration.zero; // Hesaplanan süre farkı
  String _prefix = ''; // "Kalan: ", "Başlamasına: ", "Bitti: "
  bool _isPast = false; // Süre geçti mi?

  @override
  void initState() {
    super.initState();
    _calculateDifference(); // İlk farkı hesapla
    // Sadece aktif veya yakında başlayacaksa timer başlat
    if (widget.status == ExamStatus.active ||
        widget.status == ExamStatus.upcoming) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          _calculateDifference(); // Farkı tekrar hesapla ve setState çağır
        } else {
          timer.cancel();
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _calculateDifference() {
    final now = DateTime.now();
    Duration newDifference = Duration.zero;
    String newPrefix = '';
    bool newIsPast = false;

    switch (widget.status) {
      case ExamStatus.upcoming:
        if (widget.startTime != null) {
          newDifference = widget.startTime!.difference(now);
          newPrefix = 'Başlamasına: ';
        }
        break;
      case ExamStatus.active:
        if (widget.endTime != null) {
          newDifference = widget.endTime!.difference(now);
          newPrefix = 'Bitişe Kalan: ';
          if (newDifference.isNegative) {
            // Nadir de olsa timer çalışırken süre bitebilir
            newIsPast = true;
            newDifference = now.difference(widget.endTime!);
            newPrefix = 'Bitti: ';
          }
        }
        break;
      case ExamStatus.finished:
        if (widget.endTime != null) {
          newDifference = now.difference(widget.endTime!);
          newPrefix = 'Bitti: ';
          newIsPast = true;
        }
        break;
      default:
        newPrefix = '';
    }

    // State'i sadece fark değiştiyse veya ilk kezse güncelle
    if (newDifference != _difference || _prefix == '') {
      setState(() {
        _difference = newDifference;
        _prefix = newPrefix;
        _isPast = newIsPast;
      });
    } else if (_isPast && widget.status != ExamStatus.finished) {
      // Timer çalışırken süre bittiyse timer'ı durdur
      _timer?.cancel();
    }
  }

  // Kalan/Geçen süreyi formatla
  String _formatDuration(Duration d) {
    if (d.isNegative && !_isPast)
      return '00:00'; // Henüz başlamadıysa negatif gösterme

    d = d.abs(); // Mutlak değerini al

    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String days = d.inDays > 0 ? '${d.inDays}g ' : '';
    String hours = twoDigits(d.inHours.remainder(24));
    String minutes = twoDigits(d.inMinutes.remainder(60));
    String seconds = twoDigits(d.inSeconds.remainder(60));
    if (d.inDays > 0) return '$days$hours:$minutes:$seconds';
    if (d.inHours > 0) return '$hours:$minutes:$seconds';
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.status == ExamStatus.unknown) {
      return const Text('Tarih Belirsiz'); // Veya boş Text('')
    }
    // Zamanlayıcı çalışırken süre bittiyse (ExamStatus.active ama _isPast true ise)
    // veya normalde bittiyse (ExamStatus.finished) "önce bitti" yaz.
    final suffix = _isPast ? ' önce' : '';
    return Text(
      '$_prefix${_formatDuration(_difference)}$suffix',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      overflow: TextOverflow.ellipsis, // Taşarsa ... koysun
    );
  }
}
