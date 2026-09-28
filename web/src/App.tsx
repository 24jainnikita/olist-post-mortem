import './index.css';
import { Opening } from './components/Opening';
import { Scale } from './components/Scale';

function App() {
  return (
    <main>
      <Opening />
      <Scale />

      <section id="suspect">
        <h2>Suspect</h2>
        <p className="data-number accent">Placeholder for parcel-journey timeline</p>
      </section>

      <section id="evidence">
        <h2>Evidence</h2>
        <p className="data-number accent">Placeholder for delay-threshold slider and map</p>
      </section>

      <section id="twist">
        <h2>Twist</h2>
        <p className="data-number accent">Placeholder for worst categories / sellers</p>
      </section>

      <section id="cohort-heatmap">
        <h2>Cohort Heatmap</h2>
        <p className="data-number accent">Placeholder for cohort retention matrix</p>
      </section>

      <section id="verdict">
        <h2>Verdict</h2>
        <p className="data-number accent">Placeholder for recommendations</p>
      </section>

      <section id="methodology">
        <h2>Methodology</h2>
        <p className="data-number accent">Placeholder for data gathering info</p>
      </section>
    </main>
  );
}

export default App;
