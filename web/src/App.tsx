import React, { Suspense } from 'react';
import './index.css';
import { Opening } from './components/Opening';
import { Scale } from './components/Scale';
import { Suspect } from './components/Suspect';
import { Evidence } from './components/Evidence';
import { Twist } from './components/Twist';
import { Verdict } from './components/Verdict';
import { Methodology } from './components/Methodology';

const CohortHeatmap = React.lazy(() => import('./components/CohortHeatmap').then(m => ({ default: m.CohortHeatmap })));

function App() {
  return (
    <main>
      <Opening />
      <Scale />
      <Suspect />
      <Evidence />
      <Twist />
      <Suspense fallback={<div style={{ height: '100vh', display: 'flex', alignItems: 'center', justifyContent: 'center' }}>Loading heatmap...</div>}>
        <CohortHeatmap />
      </Suspense>
      <Verdict />
      <Methodology />
    </main>
  );
}

export default App;
