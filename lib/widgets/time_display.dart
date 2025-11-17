import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // Gerekirse tarih formatı için

// Yeni enum dosyasını import et
import 'package:bilgi_yarismasi/utils/exam_status.dart';

// enum ExamStatus tanımı buradan SİLİNDİ.

class TimeDifferenceDisplay extends StatefulWidget {
  final DateTime? startTime;
  final DateTime? endTime;
  final ExamStatus status; // Bu artık utils/exam_status.dart'tan geliyor

  const TimeDifferenceDisplay({
    super.key,
    required this.startTime,
    required this.endTime,
    required this.status,
    TextStyle? textStyle,
  });

  @override
  State<TimeDifferenceDisplay> createState() => _TimeDifferenceDisplayState();
}

class _TimeDifferenceDisplayState extends State<TimeDifferenceDisplay> {
  Timer? _timer;
  Duration _difference = Duration.zero;
  String _prefix = '';
  bool _isPast = false;

  @override
  void initState() {
    super.initState();
    _calculateDifference(); // İlk farkı hesapla

    if (widget.status == ExamStatus.active ||
        widget.status == ExamStatus.upcoming) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          _calculateDifference();
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

  // didUpdateWidget eklemek iyi bir pratiktir, widget güncellendiğinde timer'ı yönetir
  @override
  void didUpdateWidget(covariant TimeDifferenceDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Durum değiştiyse timer'ı yeniden değerlendir
    if (oldWidget.status != widget.status) {
      _timer?.cancel(); // Eski timer'ı durdur
      _calculateDifference(); // Durumu hemen güncelle
      // Yeni durum hala aktif veya yakındaysa yeni timer başlat
      if (widget.status == ExamStatus.active ||
          widget.status == ExamStatus.upcoming) {
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            _calculateDifference();
          } else {
            timer.cancel();
          }
        });
      }
    }
  }

  void _calculateDifference() {
    final now = DateTime.now();
    Duration newDifference = Duration.zero;
    String newPrefix = '';
    bool newIsPast = false;

    // Geçerli durumu (status) widget'tan al
    ExamStatus currentStatus = widget.status;

    // Timer çalışırken durumun değişip değişmediğini de kontrol et
    if (widget.startTime != null && now.isBefore(widget.startTime!)) {
      currentStatus = ExamStatus.upcoming;
    } else if (widget.endTime != null && now.isAfter(widget.endTime!)) {
      currentStatus = ExamStatus.finished;
    } else if (widget.startTime != null &&
        widget.endTime != null &&
        now.isAfter(widget.startTime!) &&
        now.isBefore(widget.endTime!)) {
      currentStatus = ExamStatus.active;
    }

    switch (currentStatus) {
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
            // Süre doldu
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
        newPrefix = 'Tarih Belirsiz';
    }

    // State'i sadece fark değiştiyse veya ilk kezse güncelle
    if (newDifference != _difference || _prefix == '' || newIsPast != _isPast) {
      if (mounted) {
        setState(() {
          _difference = newDifference;
          _prefix = newPrefix;
          _isPast = newIsPast;
        });
      }
    }

    // Süre dolduysa ve timer hala çalışıyorsa durdur
    if (_isPast && _timer?.isActive == true) {
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

  // Tarihi formatla (örn: 22 Eki 14:00)
  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '';
    try {
      // 'intl' paketinin başlatıldığından emin olun (main.dart içinde)
      return DateFormat('d MMM HH:mm', 'tr_TR').format(dt);
    } catch (e) {
      return '?';
    }
  }

  @override
  Widget build(BuildContext context) {
    String textToShow = '';

    switch (widget.status) {
      case ExamStatus.upcoming:
        textToShow =
            'Başlangıç: ${_formatTimestamp(widget.startTime)} (${_formatDuration(_difference)} kaldı)';
        break;
      case ExamStatus.active:
        textToShow =
            'Bitiş: ${_formatTimestamp(widget.endTime)} (${_formatDuration(_difference)} kaldı)';
        if (_isPast)
          textToShow =
              'Süre Doldu: ${_formatTimestamp(widget.endTime)}'; // Timer geç kalırsa
        break;
      case ExamStatus.finished:
        textToShow = 'Bitti: ${_formatTimestamp(widget.endTime)}';
        break;
      default:
        textToShow = 'Sınav tarihi belirsiz.';
    }

    return Text(
      textToShow,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }
}
