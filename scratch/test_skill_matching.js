const axios = require('axios');

async function testSkillMatching() {
    console.log('🧪 Testing Skill-Based Volunteer Prioritization...');
    
    try {
        // Test Category 1 (Medical)
        console.log('\n--- Testing Category 1 (Medical) ---');
        const res1 = await axios.get('http://localhost:3000/api/nearest-volunteers?categoryId=1');
        const vols1 = res1.data;
        console.log(`Received ${vols1.length} volunteers.`);
        vols1.slice(0, 3).forEach(v => {
            console.log(`- ${v.Name} (${v.Role}) | Recommended: ${v.isRecommended}`);
        });

        // Test Category 4 (Rescue)
        console.log('\n--- Testing Category 4 (Rescue) ---');
        const res4 = await axios.get('http://localhost:3000/api/nearest-volunteers?categoryId=4');
        const vols4 = res4.data;
        console.log(`Received ${vols4.length} volunteers.`);
        vols4.slice(0, 3).forEach(v => {
            console.log(`- ${v.Name} (${v.Role}) | Recommended: ${v.isRecommended}`);
        });

        console.log('\n✅ Skill matching API test complete.');
    } catch (err) {
        console.error('❌ Test failed. Is the server running?');
        console.error(err.message);
    }
}

testSkillMatching();
