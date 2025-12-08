import React, { useState } from 'react';
import { Sparkles, X, Search, MapPin, Bed, Database, BrainCircuit, Eye, CloudLightning, Moon, Sun, Info, Workflow, Bot } from 'lucide-react';
import SearchExamples from './components/SearchExamples';
import ArchitectureModal from './components/ArchitectureModal';
import ChatInterface from './components/ChatInterface';

import ListingCard from './components/ListingCard';

function App() {
    const [query, setQuery] = useState('');
    const [results, setResults] = useState([]);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState(null);
    const [generatedSql, setGeneratedSql] = useState('');
    const [availableCities, setAvailableCities] = useState([]);
    const [mode, setMode] = useState('nl2sql'); 
    const [weight, setWeight] = useState(0.5); // Default weight for semantic search

    const [darkMode, setDarkMode] = useState(true); 
    const [showArchitecture, setShowArchitecture] = useState(false); 
    const [isChatOpen, setIsChatOpen] = useState(false); 

    const handleSearch = async (queryOverride) => {
        const searchQuery = typeof queryOverride === 'string' ? queryOverride : query;
        if (!searchQuery.trim()) return;
        setIsLoading(true);
        setError(null);
        setResults([]);
        setGeneratedSql('');
        setAvailableCities([]);

        try {
            const response = await fetch('/api/search', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ query: searchQuery, mode, weight }),
            });
            const data = await response.json();
            if (!response.ok) throw new Error(data.detail || 'Search failed');
            setResults(data.listings || []);
            setGeneratedSql(data.sql || '');
            setAvailableCities(data.available_cities || []);
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
        <div className={`${darkMode ? 'dark' : ''} min-h-screen transition-colors duration-500`}>
            <div className="min-h-screen bg-gradient-to-br from-slate-50 via-indigo-50/50 to-slate-100 dark:from-slate-950 dark:via-slate-900 dark:to-slate-950 selection:bg-indigo-100 selection:text-indigo-700 p-4 sm:p-8 font-sans text-slate-800 dark:text-slate-100 flex flex-col items-center relative overflow-x-hidden transition-colors duration-500">
            <div className="fixed inset-0 pointer-events-none">
                <div className="absolute top-[-10%] left-[-10%] w-[40%] h-[40%] bg-indigo-200/30 rounded-full blur-[120px] mix-blend-multiply animate-blob"></div>
                <div className="absolute top-[-10%] right-[-10%] w-[40%] h-[40%] bg-purple-200/30 rounded-full blur-[120px] mix-blend-multiply animate-blob animation-delay-2000"></div>
                <div className="absolute bottom-[-20%] left-[20%] w-[40%] h-[40%] bg-pink-200/30 rounded-full blur-[120px] mix-blend-multiply animate-blob animation-delay-4000"></div>
            </div>
            <div className="w-full max-w-5xl mx-auto mt-8 relative z-10">
                    <div className="bg-white/70 dark:bg-slate-900/70 backdrop-blur-xl rounded-3xl shadow-2xl border border-white/50 dark:border-slate-700/50 overflow-hidden ring-1 ring-black/5">
                    {/* Header Line */}
                        <div className={`h-2 transition-colors duration-300 ${mode === 'vertex_search' ? 'bg-orange-500' : mode === 'nl2sql' ? 'bg-teal-500' : 'bg-indigo-500'}`}></div>
                    
                    <div className="p-8">
                        <div className="flex flex-col xl:flex-row justify-between items-center mb-6 gap-4">
                                <h2 className="text-2xl font-bold text-slate-900 dark:text-white whitespace-nowrap flex items-center">
                                    Property Search <span className="text-xs font-normal text-slate-400 border border-slate-200 dark:border-slate-700 px-2 py-0.5 rounded-full ml-2">BETA</span>
                                    <button onClick={() => setShowArchitecture(true)} className="ml-2 px-3 py-1 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors text-sm font-medium flex items-center gap-2">
                                        <Workflow className="w-4 h-4" /> Architecture
                                    </button>
                                    <button onClick={() => setDarkMode(!darkMode)} className="ml-4 p-2 rounded-full bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400 hover:bg-slate-200 dark:hover:bg-slate-700 transition-colors">
                                        {darkMode ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
                                    </button>
                                </h2>
                            
                            {/* --- 4-WAY TOGGLE --- */}
                                <div className="flex bg-slate-100/50 dark:bg-slate-800/50 backdrop-blur-sm border border-slate-200/50 dark:border-slate-700/50 p-1.5 rounded-xl overflow-x-auto max-w-full shadow-inner">
                                    <button onClick={() => setMode('nl2sql')} className={`px-3 py-1.5 rounded-md text-sm font-semibold flex items-center whitespace-nowrap transition-all ${mode === 'nl2sql' ? 'bg-white dark:bg-slate-700 text-teal-600 dark:text-teal-400 shadow-sm' : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'}`}>
                                    <BrainCircuit className="w-4 h-4 mr-2" /> AlloyDB NL
                                </button>
                                    <button onClick={() => setMode('semantic')} className={`px-3 py-1.5 rounded-md text-sm font-semibold flex items-center whitespace-nowrap transition-all ${mode === 'semantic' ? 'bg-white dark:bg-slate-700 text-indigo-600 dark:text-indigo-400 shadow-sm' : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'}`}>
                                    <Database className="w-4 h-4 mr-2" /> Semantic
                                    </button>
                                    <button onClick={() => setMode('vertex_search')} className={`px-3 py-1.5 rounded-md text-sm font-semibold flex items-center whitespace-nowrap transition-all ${mode === 'vertex_search' ? 'bg-white dark:bg-slate-700 text-orange-600 dark:text-orange-400 shadow-sm' : 'text-slate-500 dark:text-slate-400 hover:text-slate-700 dark:hover:text-slate-200'}`}>
                                    <CloudLightning className="w-4 h-4 mr-2" /> Vertex AI Search
                                </button>
                            </div>
                        </div>

                            {mode !== 'agent' && (
                                <>
                                    <p className="text-slate-500 dark:text-slate-400 mb-6">
                                        {mode === 'nl2sql' && "Builder Mode: AlloyDB generates precise SQL queries for filters."}
                                        {mode === 'semantic' && (
                                            <div className="flex flex-col gap-2">
                                                <span>Builder Mode: Hybrid search combining Text and Image similarity.</span>
                                                <div className="flex items-center gap-4 bg-slate-100 dark:bg-slate-800 p-3 rounded-lg w-full max-w-md">
                                                    <span className="text-xs font-bold text-slate-500 uppercase">Image</span>
                                                    <input
                                                        type="range"
                                                        min="0"
                                                        max="1"
                                                        step="0.1"
                                                        value={weight}
                                                        onChange={(e) => setWeight(parseFloat(e.target.value))}
                                                        className="w-full h-2 bg-slate-200 rounded-lg appearance-none cursor-pointer dark:bg-slate-700 accent-indigo-500"
                                                    />
                                                    <span className="text-xs font-bold text-slate-500 uppercase">Text</span>
                                                    <span className="text-xs font-mono bg-white dark:bg-slate-900 px-2 py-1 rounded border border-slate-200 dark:border-slate-600 min-w-[3rem] text-center">
                                                        {(weight * 100).toFixed(0)}%
                                                    </span>
                                                </div>
                                            </div>
                                        )}
                                        {mode === 'vertex_search' && "Managed Mode: Fully managed 'Black Box' search service (Agent Builder)."}
                                    </p>

                                    <SearchExamples currentQuery={query} onSelectQuery={setQuery} />

                                    <div className="relative group mb-6">
                                        <div className="absolute inset-y-0 left-0 pl-4 flex items-center pointer-events-none">
                                            <Sparkles className={`h-6 w-6 transition-colors ${mode === 'vertex_search' ? 'text-orange-500' : 'text-slate-400'}`} />
                                        </div>
                                        <input type="text" className="block w-full pl-12 pr-4 py-4 bg-white dark:bg-slate-800 border-2 border-slate-200 dark:border-slate-700 rounded-xl focus:ring-0 text-lg shadow-sm text-slate-900 dark:text-white placeholder-slate-400 dark:placeholder-slate-500" placeholder="Describe your dream home..." value={query} onChange={(e) => setQuery(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && handleSearch()} />
                                    </div>


                                    <div className="flex justify-between border-t border-slate-100 dark:border-slate-700 pt-6">
                                        <button onClick={handleClear} className="text-slate-500 dark:text-slate-400 font-bold hover:text-slate-700 dark:hover:text-slate-200 px-4 py-2"><X className="inline w-4 h-4 mr-1" /> Clear</button>
                                        <button onClick={handleSearch} disabled={isLoading} className={`font-bold py-3 px-10 rounded-lg shadow-md text-white transition-all ${mode === 'vertex_search' ? 'bg-orange-500 hover:bg-orange-600' : 'bg-teal-500 hover:bg-teal-600'}`}>{isLoading ? '...' : 'Search'}</button>
                                    </div>
                                </>
                            )}
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

                {results.length === 0 && generatedSql && !isLoading && (
                        <div className="text-center py-12 bg-white/50 dark:bg-slate-800/50 backdrop-blur-sm rounded-2xl border border-slate-200 dark:border-slate-700 shadow-sm mb-8">
                            <div className="text-slate-500 dark:text-slate-400 mb-4 text-lg">No properties found matching your criteria.Try to search in Cities from below:</div>
                        {availableCities.length > 0 && (
                            <div className="text-sm text-slate-400">
                                <p className="mb-2 font-semibold uppercase tracking-wider text-xs">RESULT</p>
                                <div className="flex flex-wrap justify-center gap-2 max-w-2xl mx-auto px-4">
                                    {availableCities.map(city => (
                                        <button
                                            key={city}
                                            onClick={() => {
                                                setQuery(city);
                                                handleSearch(city);
                                            }}
                                            className="bg-white dark:bg-slate-700 px-3 py-1.5 rounded-full border border-slate-200 dark:border-slate-600 shadow-sm text-slate-600 dark:text-slate-300 hover:bg-indigo-50 dark:hover:bg-slate-600 hover:text-indigo-600 dark:hover:text-indigo-300 hover:border-indigo-200 dark:hover:border-indigo-500 transition-all cursor-pointer"
                                        >
                                            {city}
                                        </button>
                                    ))}
                                </div>
                            </div>
                        )}
                    </div>
                )}

                    <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
                        {results.map((listing, i) => <ListingCard key={i} listing={listing} />)}
                    </div>
            </div>

                {/* Floating Chat Widget */}
                <div className="fixed bottom-6 right-6 z-50 flex flex-col items-end">
                    {isChatOpen && (
                        <div className="mb-4 w-[400px] h-[600px] shadow-2xl rounded-2xl overflow-hidden animate-in fade-in slide-in-from-bottom-10 duration-300">
                            <ChatInterface
                                onClose={() => setIsChatOpen(false)}
                                onResultsFound={(agentResults, agentQuery) => {
                                    setResults(agentResults);
                                    if (agentQuery) setQuery(agentQuery);
                                    // Optionally clear other search states if needed
                                    setGeneratedSql('');
                                    setAvailableCities([]);
                                }}
                            />
                        </div>
                    )}
                    <button
                        onClick={() => setIsChatOpen(!isChatOpen)}
                        className={`group relative p-4 rounded-full shadow-2xl transition-all duration-300 transform hover:scale-110 active:scale-95 flex items-center justify-center ${isChatOpen
                                ? 'bg-slate-800 text-white hover:bg-slate-700'
                                : 'bg-gradient-to-r from-indigo-600 via-purple-600 to-pink-600 text-white hover:shadow-indigo-500/50'
                            }`}
                    >
                        {!isChatOpen && (
                            <span className="absolute -top-1 -right-1 flex h-4 w-4">
                                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-pink-400 opacity-75"></span>
                                <span className="relative inline-flex rounded-full h-4 w-4 bg-pink-500"></span>
                            </span>
                        )}
                        {isChatOpen ? <X className="w-8 h-8" /> : <Bot className="w-8 h-8" />}
                    </button>
                </div>
        </div>
            <ArchitectureModal isOpen={showArchitecture} onClose={() => setShowArchitecture(false)} />
        </div>
    );
}
export default App;