const fs = require('fs').promises;
const path = require('path');

module.exports = async (req, res) => {
  try {
    const dataPath = path.join(process.cwd(), 'data', 'programm.json');
    const fileContents = await fs.readFile(dataPath, 'utf-8');
    const programmData = JSON.parse(fileContents);
    
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Cache-Control', 's-maxage=300, stale-while-revalidate=60');
    
    res.status(200).json({
      success: true,
      count: programmData.length,
      data: programmData,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('API Fehler:', error);
    res.status(500).json({
      success: false,
      error: 'Programmdaten nicht verfügbar',
      details: process.env.NODE_ENV === 'development' ? error.message : undefined
    });
  }
};

