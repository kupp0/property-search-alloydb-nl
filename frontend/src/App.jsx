import React, { useState } from 'react';
import { Sparkles, X, Search, MapPin, Bed, Database, BrainCircuit, Eye, Loader2, Image as ImageIcon, CloudLightning } from 'lucide-react';
import SearchExamples from './components/SearchExamples';

const formatCurrency = (number) => {
    return new Intl.NumberFormat('en-US', {
        style: 'currency',
        currency: 'CHF',
        maximumFractionDigits: 0,
    }).format(number);
};

const ListingCard = ({ listing }) => {
    const [imageUrl, setImageUrl] = useState(listing.image_gcs_uri || null);
    const [isGenerating, setIsGenerating] = useState(false);

    const handleGenerateImage = async () => {
        if (imageUrl || isGenerating) return;
        setIsGenerating(true);
        try {
            const response = await fetch('/api/generate-image', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ description: listing.description }),
            });
            if (!response.ok) throw new Error("Failed");
            const data = await response.json();
            setImageUrl(data.image);
        } catch (err) {
            console.error(err);
            alert("Image generation failed.");
        } finally {
            setIsGenerating(false);
        }
    };

    return (
        <div className="bg-white/80 backdrop-blur-md rounded-2xl shadow-sm border border-white/40 overflow-hidden hover:shadow-xl hover:-translate-y-1 transition-all duration-300 flex flex-col group">
            <div className="h-48 bg-slate-100 relative overflow-hidden group">
                {imageUrl ? (
                    <img src={imageUrl} alt="Property" className="w-full h-full object-cover hover:scale-105 transition-transform duration-700" />
                ) : (
                    <div className="w-full h-full flex flex-col items-center justify-center text-slate-400 bg-slate-50">
                         {isGenerating ? (
                            <div className="flex flex-col items-center animate-pulse">
                                <Loader2 className="w-8 h-8 animate-spin text-indigo-500 mb-2" />
                                <span className="text-xs font-medium text-indigo-500">Designing...</span>
                            </div>
                        ) : (
                            <>
                                <span className="text-4xl mb-2">🏠</span>
                                <button onClick={handleGenerateImage} className="mt-2 flex items-center gap-2 bg-white px-3 py-1.5 rounded-full shadow-sm border border-slate-200 text-xs font-semibold text-indigo-600 hover:bg-indigo-50 transition-all">
                                    <ImageIcon className="w-3 h-3" /> Visualize
                                </button>
                            </>
                        )}
                    </div>
                )}
                <div className="absolute top-3 right-3 bg-white/95 px-2 py-1 rounded shadow-sm font-bold text-sm text-slate-700">
                    {listing.price ? formatCurrency(listing.price) : "N/A"}
                </div>
            </div>
            <div className="p-5 flex flex-col flex-grow">
                <h3 className="text-lg font-bold text-gray-900 mb-1 truncate">{listing.title}</h3>
                <div className="flex items-center text-gray-500 text-sm mb-4"><MapPin className="w-4 h-4 mr-1" /> {listing.city}</div>
                <div className="flex items-center gap-4 text-xs text-gray-600 mb-4 pb-4 border-b border-gray-100">
                     {listing.bedrooms !== undefined && <><Bed className="w-4 h-4 text-teal-500 mr-1" /> {listing.bedrooms} Beds</>}
                </div>
                <p className="text-sm text-gray-600 line-clamp-3">{listing.description}</p>
            </div>
        </div>
    );
};

function App() {
    const [query, setQuery] = useState('');
    const [results, setResults] = useState([]);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState(null);
    const [generatedSql, setGeneratedSql] = useState('');
    const [mode, setMode] = useState('nl2sql'); 

    const handleSearch = async () => {
        if (!query.trim()) return;
        setIsLoading(true);
        setError(null);
        setResults([]);
        setGeneratedSql('');

        try {
            const response = await fetch('/api/search', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ query, mode }),
            });
            const data = await response.json();
            if (!response.ok) throw new Error(data.detail || 'Search failed');
            setResults(data.listings || []);
            setGeneratedSql(data.sql || '');
        } catch (err) {
            setError(err.message);
        } finally {
            setIsLoading(false);
        }
    };

    const handleClear = () => {
        setQuery('');
        setResults([]);
        setError(null);
        setGeneratedSql('');
    };

    return (
        <div className="min-h-screen bg-gradient-to-br from-slate-50 via-indigo-50/50 to-slate-100 selection:bg-indigo-100 selection:text-indigo-700 p-4 sm:p-8 font-sans text-slate-800 flex flex-col items-center relative overflow-x-hidden">
            <div className="fixed inset-0 pointer-events-none">
                <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-indigo-200/30 rounded-full blur-[120px] mix-blend-multiply animate-blob"></div>
                <div className="absolute top-[-10%] right-[-10%] w-[40%] h-[40%] bg-purple-200/30 rounded-full blur-[120px] mix-blend-multiply animate-blob animation-delay-2000"></div>
                <div className="absolute bottom-[-20%] left-[20%] w-[40%] h-[40%] bg-pink-200/30 rounded-full blur-[120px] mix-blend-multiply animate-blob animation-delay-4000"></div>
            </div>
            <div className="w-full max-w-5xl mx-auto mt-8 relative z-10">
                <div className="bg-white/70 backdrop-blur-xl rounded-3xl shadow-2xl border border-white/50 overflow-hidden ring-1 ring-black/5">
                    {/* Header Line */}
                    <div className={`h-2 transition-colors duration-300 ${mode === 'vertex_search' ? 'bg-orange-500' : mode === 'nl2sql' ? 'bg-teal-500' : mode === 'semantic' ? 'bg-indigo-500' : 'bg-purple-500'}`}></div>
                    
                    <div className="p-8">
                        <div className="flex flex-col xl:flex-row justify-between items-center mb-6 gap-4">
                            <h2 className="text-2xl font-bold text-slate-900 whitespace-nowrap">Property Search <span className="text-xs font-normal text-slate-400 border border-slate-200 px-2 py-0.5 rounded-full ml-2">BETA</span></h2>
                            
                            {/* --- 4-WAY TOGGLE --- */}
                            <div className="flex bg-slate-100/50 backdrop-blur-sm border border-slate-200/50 p-1.5 rounded-xl overflow-x-auto max-w-full shadow-inner">
                                <button onClick={() => setMode('nl2sql')} className={`px-3 py-1.5 rounded-md text-sm font-semibold flex items-center whitespace-nowrap transition-all ${mode === 'nl2sql' ? 'bg-white text-teal-600 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}>
                                    <BrainCircuit className="w-4 h-4 mr-2" /> AlloyDB NL
                                </button>
                                <button onClick={() => setMode('semantic')} className={`px-3 py-1.5 rounded-md text-sm font-semibold flex items-center whitespace-nowrap transition-all ${mode === 'semantic' ? 'bg-white text-indigo-600 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}>
                                    <Database className="w-4 h-4 mr-2" /> Semantic
                                </button>
                                <button onClick={() => setMode('visual')} className={`px-3 py-1.5 rounded-md text-sm font-semibold flex items-center whitespace-nowrap transition-all ${mode === 'visual' ? 'bg-white text-purple-600 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}>
                                    <Eye className="w-4 h-4 mr-2" /> Visual
                                </button>
                                <button onClick={() => setMode('vertex_search')} className={`px-3 py-1.5 rounded-md text-sm font-semibold flex items-center whitespace-nowrap transition-all ${mode === 'vertex_search' ? 'bg-white text-orange-600 shadow-sm' : 'text-slate-500 hover:text-slate-700'}`}>
                                    <CloudLightning className="w-4 h-4 mr-2" /> Vertex AI Search
                                </button>
                            </div>
                        </div>

                        <p className="text-slate-500 mb-6">
                            {mode === 'nl2sql' && "Builder Mode: AlloyDB generates precise SQL queries for filters."}
                            {mode === 'semantic' && "Builder Mode: Search by meaning/vibe in descriptions."}
                            {mode === 'visual' && "Builder Mode: Search by visual aesthetics (pixels)."}
                            {mode === 'vertex_search' && "Managed Mode: Fully managed 'Black Box' search service (Agent Builder)."}
                        </p>

                        <SearchExamples currentQuery={query} onSelectQuery={setQuery} />

                        <div className="relative group mb-6">
                            <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                                <Sparkles className={`h-6 w-6 transition-colors ${mode === 'vertex_search' ? 'text-orange-500' : 'text-slate-400'}`} />
                            </div>
                            <input type="text" className="block w-full pl-12 pr-4 py-4 bg-white border-2 border-slate-200 rounded-xl focus:ring-0 text-lg shadow-sm" placeholder="Describe your dream home..." value={query} onChange={(e) => setQuery(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && handleSearch()} />
                        </div>

                        <div className="flex justify-between border-t border-slate-100 pt-6">
                            <button onClick={handleClear} className="text-slate-500 font-bold hover:text-slate-700 px-4 py-2"><X className="inline w-4 h-4 mr-1"/> Clear</button>
                            <button onClick={handleSearch} disabled={isLoading} className={`font-bold py-3 px-10 rounded-lg shadow-md text-white transition-all ${mode === 'vertex_search' ? 'bg-orange-500 hover:bg-orange-600' : 'bg-teal-500 hover:bg-teal-600'}`}>{isLoading ? '...' : 'Search'}</button>
                        </div>
                    </div>
                </div>
            </div>
            
            <div className="w-full max-w-6xl mx-auto mt-12">
                {error && <div className="bg-red-50 text-red-600 p-4 rounded-lg text-center mb-6">{error}</div>}
                
                {generatedSql && (
                    <div className="w-full mb-8 animate-in fade-in slide-in-from-bottom-4 duration-500">
                        <div className="bg-slate-900 rounded-lg overflow-hidden shadow-lg border border-slate-700">
                            <div className="bg-slate-800 px-4 py-2 text-xs font-mono font-bold text-slate-400">System Output</div>
                            <div className="p-4 overflow-x-auto bg-slate-950 text-green-400 font-mono text-sm whitespace-pre-wrap leading-relaxed">{generatedSql}</div>
                        </div>
                    </div>
                )}

                <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                    {results.map((listing, i) => <ListingCard key={i} listing={listing} />)}
                </div>
            </div>
        </div>
    );
}
export default App;