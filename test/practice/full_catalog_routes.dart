// Independent review routes: deliberately not derived from proof/answer tables.
import 'practice_engine_test.dart' as pilot show routes, alternateRoutes;

final fullRoutes = <String, List<String>>{
  ...pilot.routes,
  'dp02': ['C0', 'C1', 'C2', 'C4', 'C3'],
  'dp03': ['S0', 'S1', 'S2', 'S3'],
  'dp04': ['G0', 'G3', 'G4', 'G5', 'G6'],
  'dp06': ['F0', 'F1', 'F2', 'F3', 'F4'],
  'dp07': ['M0', 'M1', 'M2', 'M4', 'M5'],
  'dp08': ['I0', 'I1', 'I2', 'I3', 'I4'],
  'dp09': ['L0', 'L1', 'L2', 'L4', 'L3'],
  'dp10': ['W0', 'W1', 'W2', 'W3', 'W4'],
  'dp11': ['K0', 'K1', 'K2', 'K3'],
  'dp12': ['H0', 'H1', 'H2', 'H3', 'H4'],
  'dp14': ['A0', 'A1', 'A2', 'A3', 'A4'],
  'dp15': ['N0', 'N1', 'N2', 'N4', 'N3'],
  'dp16': ['T0', 'T1', 'T2', 'T3'],
  'dp17': ['E0', 'E1', 'E2', 'E4'],
  'dp18': ['R0', 'R1', 'R2'],
};

final fullAlternateRoutes = <String, List<String>>{
  ...pilot.alternateRoutes,
  'dp02': ['C3', 'C5', 'C0'],
  'dp03': ['S3', 'S4', 'S0'],
  'dp04': ['G6', 'G5', 'G4', 'G2', 'G1', 'G0'],
  'dp06': ['F4', 'F5', 'F0'],
  'dp07': ['M5', 'M4', 'M3', 'M1', 'M0'],
  'dp08': ['I4', 'I5', 'I1', 'I0'],
  'dp09': ['L3', 'L5', 'L0'],
  'dp10': ['W4', 'W5', 'W0'],
  'dp11': ['K4', 'K0'],
  'dp12': ['H4', 'H5', 'H0'],
  'dp14': ['A4', 'A3', 'A2', 'A5', 'A0'],
  'dp15': ['N3', 'N5', 'N0'],
  'dp16': ['T3', 'T4', 'T0'],
  'dp17': ['E4', 'E3', 'E1', 'E0'],
  'dp18': ['R2', 'R3', 'R0'],
};
