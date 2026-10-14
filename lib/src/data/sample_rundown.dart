import '../models/activity_item.dart';
import '../models/event_day.dart';

/// Itinerario de ejemplo que se carga la primera vez que se abre la app.
///
/// Reproduce un encuentro real de fin de semana (sábado y domingo) para que se
/// pueda probar el modo escenario sin capturar nada a mano. Una vez cargado no
/// vuelve a aparecer: el usuario puede editarlo o borrarlo con normalidad.
///
/// Las horas de inicio son las del itinerario original. La hora de fin **no**
/// se guarda: el motor la deduce del inicio de la actividad siguiente, igual
/// que con cualquier itinerario creado a mano.
List<EventDay> buildSampleRundown() {
  final saturday = DateTime(2026, 10, 17);
  final sunday = DateTime(2026, 10, 18);

  return [
    EventDay(
      id: 'sample-sabado',
      name: 'Sábado 17',
      date: saturday,
      activities: [
        ActivityItem(
          id: 'sat-01',
          title: 'LLEGADA BIENVENIDA, REGISTRO, PAGOS, '
              'HOJA DE VIDA DIGITAL, ESCARAPELA',
          startTime: _at(saturday, 19, 30),
          // Cierre propio: la hoja marca las 8:00 pm, pero la actividad
          // siguiente (acomodación) empieza a las 7:50 pm.
          endTime: _at(saturday, 20, 0),
          location: 'Auditorio MCI zona al frente administración',
          responsible: 'Felipe y Juan Felipe',
        ),
        ActivityItem(
          id: 'sat-02',
          title: 'ACOMODACIÓN SILLAS / BIOMBOS',
          startTime: _at(saturday, 19, 50),
          location: 'Auditorio MCI',
          responsible: 'Servicio externo',
        ),
        ActivityItem(
          id: 'sat-03',
          title: 'BIENVENIDA, PRESENTACIÓN DE ASISTENTES, '
              '2 PREGUNTAS, GUÍAS Y SERVIDORES',
          startTime: _at(saturday, 20, 0),
          location: 'Auditorio MCI',
          responsible: 'César Rojas',
        ),
        ActivityItem(
          id: 'sat-04',
          title: 'LA IMPORTANCIA DE TENER UN ENCUENTRO',
          startTime: _at(saturday, 20, 20),
          location: 'Auditorio MCI',
          responsible: 'Pastor Octavio',
        ),
        ActivityItem(
          id: 'sat-05',
          title: 'REFRIGERIO / MILO CON EMPANADA',
          startTime: _at(saturday, 21, 20),
          // Última del día: la hoja marca 9:30 pm, 10 minutos.
          endTime: _at(saturday, 21, 30),
          location: 'Auditorio MCI zona al frente administración',
          responsible: 'Equipo de servicio',
        ),
      ],
    ),
    EventDay(
      id: 'sample-domingo',
      name: 'Domingo 18',
      date: sunday,
      activities: [
        ActivityItem(
          id: 'dom-01',
          title: 'LLEGADA BIENVENIDA, REGISTRO, PAGOS, '
              'HOJA DE VIDA DIGITAL, ESCARAPELA',
          startTime: _at(sunday, 6, 30),
          location: 'Auditorio MCI',
          responsible: 'Felipe y Juan Felipe',
        ),
        ActivityItem(
          id: 'dom-02',
          title: 'REFRIGERIO / TINTO CON BUÑUELO · '
              'INGRESO BIENVENIDA, PRESENTACIÓN FALTE',
          startTime: _at(sunday, 7, 0),
          location: 'Auditorio MCI',
          responsible: 'César Rojas y Equipo de servicio',
        ),
        ActivityItem(
          id: 'dom-03',
          title: 'LA REVELACIÓN DE LA CRUZ + '
              'Video Clips «La Pasión de Cristo»',
          startTime: _at(sunday, 7, 15),
          location: 'Auditorio MCI',
          responsible: 'Andrés Fernández',
        ),
        ActivityItem(
          id: 'dom-04',
          title: 'REUNIÓN DOMINICAL',
          startTime: _at(sunday, 9, 0),
          location: 'Auditorio MCI',
          responsible: 'Pastor Octavio',
        ),
        ActivityItem(
          id: 'dom-05',
          title: 'REFRIGERIO / JUGO CON SÁNDWICH EN EL AUDITORIO · '
              'ACOMODACIÓN SILLAS / BIOMBOS · '
              'MESAS, MANTELES, SOBREMANTELES',
          startTime: _at(sunday, 10, 45),
          location: 'Auditorio MCI',
          responsible: 'Equipo de servicio y servicio externo',
        ),
        ActivityItem(
          id: 'dom-06',
          title: 'SANANDO EL CORAZÓN · PERDÓN',
          startTime: _at(sunday, 11, 0),
          location: 'Auditorio MCI',
          responsible: 'Andrés Fernández',
        ),
        ActivityItem(
          id: 'dom-07',
          title: 'GRACIAS DIOS POR TU PERDÓN / ARREPENTIMIENTO · '
              'CLÍNICA ESPIRITUAL · VIDEO',
          startTime: _at(sunday, 12, 15),
          location: 'Auditorio MCI',
          responsible: 'César Rojas',
        ),
        ActivityItem(
          id: 'dom-08',
          title: 'FOTO / ALMUERZO + DESCANSO',
          startTime: _at(sunday, 13, 30),
          location: 'Auditorio MCI',
          responsible: 'Equipo de servicio y media',
        ),
        ActivityItem(
          id: 'dom-09',
          title: 'SEMBRANDO LO MEJOR · FAMILIA',
          startTime: _at(sunday, 14, 30),
          location: 'Auditorio MCI',
          responsible: 'Felipe Escobar',
        ),
        ActivityItem(
          id: 'dom-10',
          title: 'VENCIENDO AL ADVERSARIO · LIBERACIÓN',
          startTime: _at(sunday, 15, 15),
          location: 'Auditorio MCI',
          responsible: 'Pastor Octavio',
        ),
        ActivityItem(
          id: 'dom-11',
          title: 'INTEGRACIÓN POR GRUPOS',
          startTime: _at(sunday, 16, 45),
          location: 'Auditorio MCI',
          responsible: 'César Rojas y guías',
        ),
        ActivityItem(
          id: 'dom-12',
          title: 'EL ESPÍRITU SANTO',
          startTime: _at(sunday, 17, 30),
          location: 'Auditorio MCI',
          responsible: 'Pastor Octavio',
        ),
        ActivityItem(
          id: 'dom-13',
          title: 'CORRESPONDENCIA · SE ESTARÁ RECIBIENDO '
              'DE 11:00 AM HASTA 1:00 PM',
          startTime: _at(sunday, 18, 45),
          location: '2DO PISO Auditorio MCI',
          responsible: 'Guías',
        ),
        ActivityItem(
          id: 'dom-14',
          title: 'FIESTA DE BIENVENIDA',
          startTime: _at(sunday, 19, 20),
          // Última del día: la hoja marca 8:30 pm, 70 minutos.
          endTime: _at(sunday, 20, 30),
          location: 'Auditorio MCI',
          responsible: 'César Rojas y Andrés Fernández',
        ),
      ],
    ),
  ];
}

DateTime _at(DateTime day, int hour, int minute) =>
    DateTime(day.year, day.month, day.day, hour, minute);
